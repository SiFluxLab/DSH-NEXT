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
     * Consume the fully expanded PRoot argv (overlays, binds and guest env are
     * already composed by [DshProcess]) and turn it into a loader invocation.
     */
    fun prepare(rootfs: File, abi: String, argv: List<String>, hostEnv: Map<String, String>): Plan {
        val loaderName = ABI_LOADER[abi] ?: error("yinglong: unsupported ABI $abi")
        check(unavailable(rootfs, abi) == null) { "yinglong: ${unavailable(rootfs, abi)}" }
        val root = rootfs.canonicalFile
        val rootPath = root.path

        val envAt = argv.indexOf("/usr/bin/env")
        require(envAt > 1 && argv.getOrNull(envAt + 1) == "-i") { "yinglong: missing guest environment" }

        // 1. Guest-visible environment: the `env -i` arguments, up to the shell.
        val guest = ArrayList<String>()
        var i = envAt + 2
        while (i < argv.size && argv[i].contains('=')) {
            val name = argv[i].substringBefore('=')
            require(Regex("[A-Za-z_][A-Za-z0-9_]*").matches(name)) { "yinglong: invalid environment name" }
            guest += argv[i++]
        }
        require(argv.drop(i).take(2) == listOf("/bin/sh", "-c") && argv.size == i + 3) { "yinglong: unsupported guest command" }
        val script = argv.last()
        require('\u0000' !in script && '\n' !in script && '\r' !in script) { "yinglong: invalid guest command" }

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
        val ztBind = binds.entries.joinToString(";") { (guestPath, host) -> "$guestPath=$host" }

        // 3. Loader, libraries and the first executable — all host paths.
        val loader = File(root, "$DIR/$loaderName").path
        val libraries = libraryDirectories(abi).joinToString(":") { File(root, it).path }
        val env = File(root, "usr/bin/env").path

        val zt = linkedMapOf(
            "ZT_ROOT" to rootPath,
            "ZT_FAKE_ROOT" to "1",
            "ZT_LD" to loader,
            "ZT_LIBPATH" to libraries,
        )
        if (ztBind.isNotEmpty()) zt["ZT_BIND"] = ztBind
        // Children only see what `env -i` carries; the app's own process gets both.
        guest += zt.map { (k, v) -> "$k=$v" }

        val cmd = arrayListOf(loader, "--library-path", libraries, env, "-i")
        cmd += guest
        cmd += listOf("/bin/sh", "-c", script)

        val environment = LinkedHashMap<String, String>()
        hostEnv.forEach { (k, v) -> if (!k.startsWith("PROOT_") && k != "LD_PRELOAD" && k != "LD_LIBRARY_PATH") environment[k] = v }
        environment.putAll(zt)
        return Plan(cmd, environment, File(root, "root"))
    }
}
