# flutter_application_3

A new Flutter project.

DashboardPage
  watches categoriesProvider / listSummariesProvider
    ↓
categoriesProvider / listSummariesProvider
  watch listTrackerRepositoryProvider
    ↓
listTrackerRepositoryProvider
  watches appDatabaseProvider
    ↓
appDatabaseProvider
  creates AppDatabase()

AppDatabase is initialized in repository_providers.dart,
inside appDatabaseProvider,
when the UI first watches/reads a provider that depends on it.

It is lazy, which means Flutter does not create the database at app startup unless some screen actually asks for data.