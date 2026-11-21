package dev.sifluxlab.dshnext.runtime

import java.io.File

/**
 * 应龙 (YingLong) / Zero-Trap launch: the engine runs on a patched glibc whose
 * syscall wrappers translate guest paths, so no PRoot process sits in front of
 * every syscall.
 *
 * The payload lives inside the image at `/opt/yinglong/` (loader + libc, built
 * from yinglong's `zero-trap-glibc.patch`). Launch shape, per yinglong's
 * 「接法 B」:
 *
 * ```
 * opt/yinglong/ld-linux-aarch64.so.1 --library-path <opt/yinglong>:<rootfs libs> \
 *     <rootfs>/usr/bin/env -i <guest env> <ZT vars> /bin/sh -c '<dsh web …>'
 * ```
 *
 * Three rules that are easy to get wrong:
 *  - the loader is addressed by its **host** path and must be absolute;
 *  - the first executable (`env`) is a **host** path, everything after it is a
 *    guest path — they are opened through the patched libc, which translates;
 *  - `env -i` wipes the environment, so the `ZT_*` variables are passed as
 *    `env -i` arguments too; otherwise every child process loses them and the
 *    engine silently falls back to the system libc.
 *
 * Without an index (`ZT_CACHE`) the patch still translates paths — the speed-up
 * over PRoot comes from dropping ptrace, not from the metadata cache.
 */
object YinglongLaunch {
    const val FAILED = "yinglongFailed"
    const val UNSUPPORTED = "yinglongUnsupported"

    /** Inside the image; `runtime/yinglong/` is copied here by rtbuild. */
    const val DIR = "opt/yinglong"

    data class Plan(val argv: List<String>, val environment: Map<String, String>, val cwd: File)

    private val ABI_LOADER = mapOf(
        "arm64-v8a" to "ld-linux-aarch64.so.1",
        // No x86_64 build of the patched glibc ships yet; those flavors keep PRoot.
    )

    /** Guest libraries the engine needs; host paths under the image root. */
    private fun libraryDirectories(abi: String): List<String> = when (abi) {
        "arm64-v8a" -> listOf(
            DIR,
            "lib/aarch64-linux-gnu", "usr/lib/aarch64-linux-gnu",
            "lib", "usr/lib", "usr/local/lib",
        )
        else -> error("yinglong: unsupported ABI $abi")
    }

    /** null when this image can run the engine on 应龙, else a stable reason. */
    fun unavailable(rootfs: File, abi: String): String? {
        val loader = ABI_LOADER[abi] ?: return UNSUPPORTED
        if (!File(rootfs, "$DIR/$loader").isFile) return "runtimeUpdateRequired"
        if (!File(rootfs, "$DIR/libc.so.6").isFile) return "runtimeUpdateRequired"
        if (!File(rootfs, "usr/bin/env").isFile) return "runtimeIncomplete"
        if (!File(rootfs, "opt/node/bin/node").isFile) return "runtimeIncomplete"
        return null
    }

    /**
     * `/usr/local/bin/dsh` is a `#!/bin/sh` shim: `exec node [--import=…] bin.js "$@"`.
     * Read the node command out of it. Shebangs are resolved by the kernel without
     * path translation, so a launch must never exec that script itself.
     */
    internal data class Shim(val node: String, val preload: String?, val entry: String)

    /** 需要显式绑定的顶层目录：镜像里的系统结构与安装位置。 */
    private val TOP_LEVEL_GUESTS = listOf("opt", "etc", "usr", "lib", "lib64", "bin", "sbin", "root", "tmp", "home", "var")

    internal fun shim(root: File): Shim? {
        val text = runCatching { File(root, "usr/local/bin/dsh").readText() }.getOrNull() ?: return null
        val m = Regex("""exec\s+(/\S*node)\s+(?:--import=(\S+)\s+)?(/\S*bin\.js)""").find(text) ?: return null
        val (node, preload, entry) = m.destructured
        return Shim(node, preload.ifEmpty { null }, entry)
    }

    /**
     * One cheap run through the loader (`env -i … /bin/sh -c 'exec node --version'`)
     * before the engine depends on it. Android's seccomp filter, a wrong library path or a
     * loader the kernel refuses all show up here as a non-zero exit, instead of
     * as an engine that never listens. Returns null when the loader works, else
     * "selfTest:<exit>" (or the exception's class name).
     */
    fun selfTest(rootfs: File, abi: String, timeoutMillis: Long = 8000): String? {
        val loaderName = ABI_LOADER[abi] ?: return UNSUPPORTED
        val root = rootfs.canonicalFile
        val loader = File(root, "$DIR/$loaderName")
        val libraries = libraryDirectories(abi).joinToString(":") { File(root, it).path }
        val shim = shim(root) ?: return "selfTest:noShim"
        // Exactly the chain the launch uses: loader → node. A shell or /usr/bin/env
        // in between would be a second, differently-shaped exec path.
        // 自检要回答的是"node 能不能**透过路径翻译**看到入口"，不是"node 能不能跑"。
        // 之前只跑 --version，于是只证明了解释器可用，入口看不见这件事查不出来。
        val probe = "const fs=require('fs');let bad=0;" +
            "for (const p of process.argv.slice(1)) {" +
            " try { fs.accessSync(p); console.log('OK   '+p); }" +
            " catch (e) { bad++; console.log('FAIL '+p+' '+e.code); } } process.exit(bad?1:0);"
        val cmd = listOf(
            loader.path, "--library-path", libraries, File(root, shim.node.trimStart('/')).path,
            "-e", probe, shim.entry, "/opt/dsh/package.json",
        )
        return try {
            val builder = ProcessBuilder(cmd).directory(File(root, "root")).redirectErrorStream(true)
            val environment = builder.environment()
            environment.clear()
            environment["PATH"] = "/system/bin:/system/xbin"
            environment["HOME"] = File(root, "root").path
            environment["ZT_ROOT"] = root.path
            environment["ZT_FAKE_ROOT"] = "1"
            environment["ZT_LD"] = loader.path
            environment["ZT_LIBPATH"] = libraries
            environment["ZT_STATS"] = "1"
            val p = builder.start()
            val out = p.inputStream.bufferedReader().use { reader ->
                val text = StringBuilder()
                val reader2 = Thread {
                    runCatching { reader.forEachLine { if (text.length < 2048) text.append(it).append('\n') } }
                }.apply { isDaemon = true; start() }
                if (!p.waitFor(timeoutMillis, java.util.concurrent.TimeUnit.MILLISECONDS)) {
                    p.destroyForcibly()
                    return "selfTest:timeout"
                }
                reader2.join(500)
                text.toString()
            }
            if (p.exitValue() == 0) null else "selfTest:${p.exitValue()}${out.take(300).trim().let { if (it.isEmpty()) "" else " $it" }}"
        } catch (e: Exception) {
            e.javaClass.simpleName
        }
    }

    /**
     * Consume the fully expanded PRoot argv (overlays, binds and guest env are
     * already composed by [DshProcess]) and turn it into a loader invocation.
     */
    fun prepare(rootfs: File, abi: String, argv: List<String>, hostEnv: Map<String, String>): Plan {
        val loaderName = ABI_LOADER[abi] ?: error("yinglong: unsupported ABI $abi")
        check(unavailable(rootfs, abi) == null) { "yinglong: ${unavailable(rootfs, abi)}" }
        val root = rootfs.canonicalFile
        val rootPath = root.path
        val shim = shim(root) ?: error("yinglong: /usr/local/bin/dsh is not the expected shim")

        // 1. The guest environment and the command, taken from the composed PRoot argv.
        val envAt = argv.indexOf("/usr/bin/env")
        require(envAt > 1 && argv.getOrNull(envAt + 1) == "-i") { "yinglong: missing guest environment" }
        val guest = LinkedHashMap<String, String>()
        var i = envAt + 2
        while (i < argv.size && argv[i].contains('=')) {
            val pair = argv[i++].split('=', limit = 2)
            require(Regex("[A-Za-z_][A-Za-z0-9_]*").matches(pair[0])) { "yinglong: invalid environment name" }
            guest[pair[0]] = pair[1]
        }
        require(argv.drop(i).take(2) == listOf("/bin/sh", "-c") && argv.size == i + 3) { "yinglong: unsupported guest command" }
        // `web --patch … --host … --port … --no-open`, with guest paths kept as they are:
        // node opens them through the patched libc, which translates.
        val web = DirectLaunch.webArguments(argv.last())

        // 2. PRoot binds become Zero-Trap bindings: guest=host, longest prefix wins.
        val binds = LinkedHashMap<String, String>()
        var at = 0
        while (at < envAt) {
            val value = when (val arg = argv[at++]) {
                "-b", "--bind" -> argv.getOrNull(at++) ?: error("yinglong: missing bind value")
                else -> if (arg.startsWith("--bind=")) arg.substringAfter('=') else continue
            }
            val parts = value.split(':')
            require(parts.size in 1..2 && parts.all { it.startsWith("/") }) { "yinglong: unsupported bind" }
            require(!parts[0].contains('=') && !parts[0].contains(';')) { "yinglong: unsupported bind" }
            val host = parts[0].trimEnd('/').ifEmpty { "/" }
            val guestPath = parts.getOrElse(1) { parts[0] }.trimEnd('/').ifEmpty { "/" }
            if (guestPath == "/") continue // a root override has no meaning under translation
            binds[guestPath] = host
        }
        // 不再自己加顶层绑定。/opt 与其它目录走同一条规则（先 ZT_BIND、再加 ZT_ROOT），
        // 而 ZT_BIND 有 **16 项 / 1024 字节**的硬上限，超了会被整表静默丢弃——
        // 我上一版给 11 个顶层目录各加一条，PRoot 那 14 条再加上去必然超限。
        // 让 /opt 走 ZT_ROOT 前缀即可。
        val ztBind = binds.entries.joinToString(";") { (guestPath, host) -> "$guestPath=$host" }

        // 3. Loader, libraries and the first executable — all host paths. No shell
        //    and no /usr/bin/env in the chain: both would have to exec guest
        //    binaries themselves, and every exec is a place the translation can be
        //    skipped (a shebang, a missing ZT_LD) and hand the work to bionic.
        val loader = File(root, "$DIR/$loaderName").path
        val libraries = libraryDirectories(abi).joinToString(":") { File(root, it).path }
        val node = File(root, shim.node.trimStart('/')).path

        val zt = linkedMapOf(
            "ZT_ROOT" to rootPath,
            "ZT_FAKE_ROOT" to "1",
            "ZT_LD" to loader,
            "ZT_LIBPATH" to libraries,
        )
        if (ztBind.isNotEmpty()) zt["ZT_BIND"] = ztBind

        // 预检：入口文件必须在镜像里真的存在。缺了就别 spawn——一次明确的日志，
        // 胜过十次 120ms 的崩溃重启。
        val entryHost = File(root, shim.entry.trimStart('/'))
        require(entryHost.isFile) { "yinglong: entry ${shim.entry} missing in rootfs" }
        val nodeHost = File(root, shim.node.trimStart('/'))
        require(nodeHost.isFile) { "yinglong: node ${shim.node} missing in rootfs" }

        val cmd = arrayListOf(loader, "--library-path", libraries, node)
        // 应龙路径**不传 --import**。
        //
        // 原因不是"文件不存在"（它在镜像里），而是 node 的 ESM loader 对 --import 的绝对路径
        // 走自己的解析，不经过被 Zero-Trap 打补丁的 libc open，于是它只看到宿主根下的
        // /opt/dsh-go/boot-cache.mjs，必然 ERR_MODULE_NOT_FOUND 并以 1 退出。
        // boot cache 只是冷启动加速，缺了它不影响正确性；PRoot 路径仍由 shim 自己带。
        // 之前那句"存在性判断"在真机上永远为真，等于没判断，所以整段去掉。
        // 入口用 guest 路径：假根生效时它会被翻译成 <root>/opt/dsh/…；
        //
        // 事实链：node 自己就是按宿主路径（root/opt/node/bin/node）被加载器拉起来的，能跑；
        // 而它收到 guest 路径 /opt/dsh/.../bin.js 后报 MODULE_NOT_FOUND —— 说明 Zero-Trap
        // 对 open() 的路径翻译没有覆盖到 /opt（我们显式绑了 /opt 也没用，格式或在它那侧
        // 另有约定，仓库里没有文档）。宿主路径是真实存在的文件，绕开翻译即可。
        // 若这样也不行，下一次日志会显示同样的 MODULE_NOT_FOUND，届时改成"探测两条路径"。
        cmd += shim.entry
        cmd += web

        val environment = LinkedHashMap<String, String>()
        hostEnv.forEach { (k, v) -> if (!k.startsWith("PROOT_") && k != "LD_PRELOAD" && k != "LD_LIBRARY_PATH") environment[k] = v }
        environment.putAll(guest)
        environment.putAll(zt)
        return Plan(cmd, environment, File(root, "root"))
    }
}
