# Karate Microservices Testing

Karate-based API, integration, and helper flows for the AHSS microservices platform. The project packages reusable feature files, shared JS/Java utilities, and dedicated runners so teams can exercise real services or mocks from Gradle, CI, or a Docker image.

## Highlights

- Karate 1.5.x, JUnit 5, and Java 21 via the Gradle 8.6 wrapper and toolchain-friendly build.
- Organized feature suites for domains under `src/test/resources/api` plus shared auth, helper, schema, and utility assets under `src/test/resources/common`.
- Java runners (`ApiRunnerTest`, `CustomRunnerTest`, `IntegrationRunnerTest`, `MockRunnerTest`, and per-endpoint runners in `runners/api`) expose tagging, parallelism, and mock-server controls through system properties.
- Supporting stubs (`KafkaHelper`, `ContractVerifier`, `CustomValidators`), JSON request templates, and Gatling scaffolding make it easy to extend into async/contracts/performance testing when needed.

## Requirements

- JDK 21 (the Gradle toolchain will download one if needed).
- Docker (optional) if you intend to containerize the mock server runner defined in `Dockerfile`.
- Access to either a real environment (`BASE_URL`, `AUTH_BASE_URL`, credentials) or a Karate mock feature you control.

## Setup

1. From the repo root (`shared-services-main/karate-microservices-testing`), run `./gradlew --version` once to download the Gradle 8.6 wrapper distribution.
2. Copy `.env.example` to `.env` (or export equivalent variables) to define `BASE_URL`, `AUTH_BASE_URL`, `CLIENT_ID`, `CLIENT_SECRET`, etc.
3. Execute `./gradlew test -Dkarate.env=dev` to confirm the toolchain works. The default `dev` env attempts to spin up `classpath:mocks/mock-server.feature`, so create that feature or override `-Dmock.use=false` / `USE_MOCK=false` until a mock exists.

### Repository configuration (Nexus + Maven local)

- Gradle resolution order is local → Nexus → Central. Configure credentials and URLs via environment or `-D` system properties:
  - Environment: `NEXUS_URL`, `NEXUS_USERNAME`, `NEXUS_PASSWORD`
  - System props: `-Dnexus.url=... -Dnexus.username=... -Dnexus.password=...`
- Gradle uses `mavenLocal()` and a Nexus repository entry in `build.gradle` (`build.gradle:17`). Example:
  ```bash
  NEXUS_URL=https://nexus.company.com/repository/maven-public/ \
  NEXUS_USERNAME=alice \
  NEXUS_PASSWORD=secret \
  ./gradlew build
  ```
- Maven uses a local file repository plus Nexus and Central in `pom.xml` (`pom.xml:24`). Set Nexus URLs via env:
  - `NEXUS_URL` and (optional) `NEXUS_SNAPSHOTS_URL`
- Provide credentials in `~/.m2/settings.xml` with matching server IDs:
  ```xml
  <servers>
    <server>
      <id>nexus</id>
      <username>${env.NEXUS_USERNAME}</username>
      <password>${env.NEXUS_PASSWORD}</password>
    </server>
    <server>
      <id>nexus-snapshots</id>
      <username>${env.NEXUS_USERNAME}</username>
      <password>${env.NEXUS_PASSWORD}</password>
    </server>
  </servers>
  ```

### Installing Gatling Gradle plugin to local Maven (when Nexus lacks it)

- The Gradle plugin `id 'io.gatling.gradle' version '3.11.5'` resolves from the Gradle Plugin Portal. If your Nexus doesn’t proxy it, prefetch the plugin into local Maven so Gradle can find it via `mavenLocal()`.
- Fetch to local Maven with the plugin coordinates published on the Plugin Portal [plugins.gradle.org – io.gatling.gradle]:
  ```bash
  mvn -q dependency:get -Dartifact=io.gatling.gradle:io.gatling.gradle.gradle.plugin:3.11.5
  ```
- Ensure Gradle reads plugins from local/Nexus by adding `pluginManagement` in `settings.gradle` of this project:
  ```groovy
  pluginManagement {
    repositories {
      mavenLocal()
      maven {
        url = System.getProperty('nexus.url', System.getenv('NEXUS_URL') ?: 'https://nexus.company.com/repository/gradle-plugins/')
        credentials {
          username = System.getProperty('nexus.username', System.getenv('NEXUS_USERNAME'))
          password = System.getProperty('nexus.password', System.getenv('NEXUS_PASSWORD'))
        }
      }
      gradlePluginPortal()
    }
  }
  ```
- After that, Gradle will locate `io.gatling.gradle` from local Maven if Nexus doesn’t have it.

#### Install from local files (offline)

If you already have the plugin JARs on disk and cannot fetch from the internet, install both the plugin marker and implementation into `~/.m2`:

- Plugin marker (coordinates used by Gradle’s plugins DSL):
  ```bash
  mvn install:install-file \
    -Dfile=/io.gatling.gradle.gradle.plugin-3.11.5.jar \
    -DgroupId=io.gatling.gradle \
    -DartifactId=io.gatling.gradle.gradle.plugin \
    -Dversion=3.11.5 \
    -Dpackaging=jar
  ```
- Plugin implementation (actual Gradle plugin code):
  ```bash
  mvn install:install-file \
    -Dfile=/path/to/gatling-gradle-plugin-3.11.5.jar \
    -DgroupId=io.gatling \
    -DartifactId=gatling-gradle-plugin \
    -Dversion=3.11.5 \
    -Dpackaging=jar
  ```

Tip: If you also have the `.pom` files, prefer using `-DpomFile=/path/to/*.pom` instead of specifying coordinates to ensure metadata matches.

## Running tests

### Gradle tasks

| Command | Description |
| --- | --- |
| `./gradlew test -Dkarate.env=qa -Dthreads=5` | Run the full suite (defaults to `ApiRunnerTest`). System props `include.tags` / `exclude.tags` cascade into the runners. |
| `./gradlew test --tests "*ApiRunnerTest" -Dinclude.tags=@smoke` | Run only `api/*.feature` with an include tag list. |
| `./gradlew test --tests "*CustomRunnerTest" -Dkarate.options="classpath:api/users.feature --tags @ignore --threads 1 --env qa"` | Use the custom runner to mirror `karate` CLI syntax from a single JVM option string. |
| `./gradlew test --tests "*IntegrationRunnerTest" -Duse.mock=false -Dkarate.env=qa` | Execute future service/integration flows. When `use.mock=true` (default) it will start the mock feature defined by `src/test/resources/mocks/mock-server.feature`. |
| `./gradlew test --tests "*MockRunnerTest" -Dmock.port=8090 -Dmock.block.ms=300000` | Keep the standalone mock server alive for 5 minutes—handy for manual testing or Docker. |
| `./gradlew testSmoke [-Dkarate.env=qa]`<br>`./gradlew testContract`<br>`./gradlew testPerf`<br>`./gradlew mockStart` | Convenience tasks defined in `build.gradle`. `testPerf` is wired for a future `PerformanceTestRunner`, so today it becomes a no-op until you add that class. `mockStart` runs any `*MockRunner` tests headlessly. |

Example of pointing at a remote environment while forcing a rerun with verbose logging:

```bash
BASE_URL=https://api.workshop.dennisdao.com \
  ./gradlew test --tests "*CustomRunnerTest" \
  -Dkarate.options="classpath:api" \
  -Dkarate.env=qa \
  --info --rerun-tasks
```

Maven example pointing at the same remote environment:

```bash
BASE_URL=https://api.workshop.dennisdao.com \
  mvn test \
  -Dtest='*CustomRunnerTest' \
  -Dkarate.options="classpath:api" \
  -Dkarate.env=qa
```

### Makefile shortcuts

The Makefile is designed to be invoked from the monorepo root (`shared-services-main`). Example:

```bash
# From shared-services-main/
make -f karate-microservices-testing/Makefile test env=qa threads=10
make -f karate-microservices-testing/Makefile test-smoke env=dev
```

Inside this repository it is easier to call `./gradlew …` directly because the Makefile hard-codes the `karate-microservices-testing` sub-path.

### Maven runs

| Command | Description |
| --- | --- |
| `mvn test -Dkarate.env=qa -Dthreads=5` | Run the full suite with JUnit 5 runners (defaults similar to Gradle `test`). |
| `mvn test -Dtest='*ApiRunnerTest' -Dkarate.env=qa` | Run only `ApiRunnerTest` across `classpath:api` features. |
| `mvn test -Dtest='*CustomRunnerTest' -Dkarate.env=qa -Dmock.server.enabled=true -Dmock.port=8090 -Dkarate.options="classpath:api"` | Equivalent to the Gradle CustomRunner example with mock server enabled. |
| `mvn test -Dtest='*IntegrationRunnerTest' -Duse.mock=false -Dkarate.env=qa` | Run integration flows against real endpoints, disabling mocks. |
| `mvn test -Dtest='*MockRunnerTest' -Dmock.port=8090 -Dmock.block.ms=300000` | Start the mock server and keep it alive for 5 minutes. |

Tip: On zsh, quote or escape globs so the shell doesn’t expand them. Examples: `-Dtest='*CustomRunnerTest'` or `-Dtest=\*CustomRunnerTest`.

### Windows (PowerShell and CMD)

PowerShell:

```powershell
$env:BASE_URL = "https://api.workshop.dennisdao.com"
.\gradlew.bat test --tests "*CustomRunnerTest" -Dkarate.options="classpath:api" -Dkarate.env=qa --info --rerun-tasks
mvn test -Dtest='*CustomRunnerTest' -Dkarate.options="classpath:api" -Dkarate.env=qa
```

CMD:

```bat
set BASE_URL=https://api.workshop.dennisdao.com
gradlew.bat test --tests "*CustomRunnerTest" -Dkarate.options="classpath:api" -Dkarate.env=qa --info --rerun-tasks
mvn test -Dtest="*CustomRunnerTest" -Dkarate.options="classpath:api" -Dkarate.env=qa
```

### Mock server + Docker

- `karate-config.js` automatically starts `classpath:mocks/mock-server.feature` when `karate.env=dev`. Create that feature (e.g., copy it from another repo) or disable mock mode with `-Dmock.use=false` / `USE_MOCK=false`.
- `MockRunnerTest` uses the same feature and blocks for `mock.block.ms` milliseconds. You can package it via the provided `Dockerfile`, but be aware the image expects a `docker-entrypoint.sh` script (not checked in). Add the script before building or adjust the Dockerfile accordingly.

### Performance (Gatling)

- Simulations live under `src/gatling/scala/performance/simulations`. The example class is `performance.simulations.KaratePerformanceSimulation`.
- Feature paths must exist (use `classpath:api` or a specific feature like `classpath:api/users.feature`). If you use `--tags`, ensure those tags are present in the features.
- On macOS ARM, native Netty SSL is provided automatically via the build configuration.

Gradle examples:

```bash
./gradlew gatlingRun \
  -PgatlingSimulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api/users.feature" \
  -Dkarate.env=qa \
  -Dinjection=ramp \
  -DusersPerSec=5 \
  -DdurationSeconds=120 \
  --info --rerun-tasks
```

Run all API features with constant rate for 60s:

```bash
./gradlew gatlingRun \
  -PgatlingSimulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api" \
  -Dkarate.env=qa \
  -Dinjection=constant \
  -DusersPerSec=10 \
  -DdurationSeconds=60
```

Maven examples:

```bash
mvn gatling:test \
  -Dgatling.simulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api/users.feature" \
  -Dkarate.env=qa \
  -Dthreads=10
```

Filter by tags (ensure tags exist in features):

```bash
mvn gatling:test \
  -Dgatling.simulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api --tags @perf" \
  -Dkarate.env=qa \
  -Dthreads=10
```

Run with ramp injection for 120s at 5 users/sec:

```bash
mvn gatling:test \
  -Dgatling.simulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api" \
  -Dkarate.env=qa \
  -Dinjection=ramp \
  -DusersPerSec=5 \
  -DdurationSeconds=120
```

Run with constant injection for 60s at 10 users/sec:

```bash
mvn gatling:test \
  -Dgatling.simulationClass=performance.simulations.KaratePerformanceSimulation \
  -Dkarate.options="classpath:api" \
  -Dkarate.env=qa \
  -Dinjection=constant \
  -DusersPerSec=10 \
  -DdurationSeconds=60
```

## Configuration + shared assets

- `src/test/resources/karate-config.js` centralizes environment detection. Supported knobs include `karate.env`, `mock.use`/`USE_MOCK`, `BASE_URL`, `AUTH_BASE_URL`, `MOCK_SERVER_URL`, and the automatic header configuration via `common/headers/common-headers.js`.
- Auth helpers (`common/auth/login.feature`, `oauth2.feature`) expect `USERNAME` / `PASSWORD` overrides or fallback defaults. Their token output is stored in `auth.token` for use by the header function.
- Helper flows in `common/helpers/*.feature` encapsulate create/read/update/delete logic for users, payments, and roles. Many of them read JSON bodies from `common/helpers/data/request/*.json`.
- Validation support lives in `common/schemas/*.json`, `common/utils/validators.js`, `common/utils/retry-logic.feature`, and Java classes inside `src/test/java/com/ahss/automation/helpers`.
- `KafkaHelper` currently returns stubbed payloads—replace the TODOs with real Kafka clients and wire brokers via `KAFKA_BROKERS` / `KAFKA_GROUP_ID`.
- `ContractVerifier` and `CustomValidators` are minimal but ready for expansion when you add richer schema enforcement or Karate `match` custom functions.

## Project layout

```
karate-microservices-testing/
├── src
│   ├── test/java/com/ahss/automation
│   │   ├── helpers/{ContractVerifier,CustomValidators,KafkaHelper}.java
│   │   └── runners/{ApiRunnerTest,CustomRunnerTest,IntegrationRunnerTest,MockRunnerTest}.java
│   │       └── api/{PaymentsApiRunner,TenantApiRunner,UserGroupsApiRunner,UsersApiRunner}.java
│   ├── test/resources
│   │   ├── api/{dashboard,modules,payments,permissions,products,roles,tenants,user-groups,users}.feature
│   │   └── common/{auth,headers,helpers,schemas,utils}
│   └── gatling/scala/performance/simulations/   # placeholder for Karate-Gatling sims
├── build.gradle / gradle.properties / gradlew   # Gradle + toolchain config
├── Makefile                                     # monorepo-friendly Gradle wrappers
├── Dockerfile                                   # multi-stage image for MockRunnerTest
├── .env.example                                 # sample environment variables
└── bin/                                         # compiled classes after Gradle builds
```

## Reports & artifacts

- Karate HTML reports: `build/karate-reports/karate-summary.html`.
- JUnit results: `build/reports/tests/test/index.html` and XML files under `build/test-results/test`.
- Cucumber JSON: enable via `-Dkarate.options="--report json"` or by running a runner's `main()` (they already call `.outputCucumberJson(true)`).

## Troubleshooting

- **401 / login failures** – Ensure `USERNAME`/`PASSWORD` (or `CLIENT_ID`/`CLIENT_SECRET` for OAuth) point to real credentials; when targeting mocks, set `BASE_URL`/`AUTH_BASE_URL` to the mock server.
- **Mock server errors** – `MockRunnerTest` and `karate-config.js` both expect `src/test/resources/mocks/mock-server.feature`. Create it or supply `-Dmock.feature.file=/path/to/feature` (and `-Dmock.use=false` when you do not want auto-start behavior).
- **Makefile paths** – Because the commands are hard-coded to `./karate-microservices-testing/...`, invoke the Makefile from the parent directory or adjust it to use local `./gradlew`.
- **Missing Docker entrypoint** – Provide `docker-entrypoint.sh` (or edit the Dockerfile) before building otherwise the image build will fail at the `COPY` step.
- **Timeouts / flakiness** – Tune `connectTimeout`, `readTimeout`, and `retryConfig` directly in `karate-config.js` or via system properties; reserve retries for safe/idempotent GET flows.
- **No requests generated in Gatling** – Confirm `-Dkarate.options` points to existing features (e.g., `classpath:api`) and that any `--tags` used actually exist; otherwise Gatling will exit without sending requests.
- **Netty native SSL on macOS ARM** – The build includes `io.netty:netty-tcnative-boringssl-static` to avoid `UnsatisfiedLinkError: no netty_tcnative_aarch_64`. No extra setup is needed when running Gradle or Maven.

## Extending the suite

- Add new domain tests under `src/test/resources/api` and wire a dedicated runner in `src/test/java/com/ahss/automation/runners/api` if you want isolated JUnit classes.
- Share test data or helper logic by creating new feature fragments inside `common/helpers` or Java helpers inside `com.ahss.automation.helpers`.
- When new message or contract validations are needed, update `common/schemas/*.json` and extend `ContractVerifier` / `CustomValidators` accordingly.
- Keep tags consistent (`@ignore` for quarantined scenarios, `@name=*` blocks for Karate's named steps) so Gradle filters behave predictably in CI.
