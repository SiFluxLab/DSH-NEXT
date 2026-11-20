// Run with the repository's unchanged PhoneToolCatalog.kt and Json.kt.
import dev.sifluxlab.dshnext.phone.PhoneToolCatalog
import dev.sifluxlab.dshnext.phone.Json
fun main() { print(Json.write(PhoneToolCatalog.listJson())) }
