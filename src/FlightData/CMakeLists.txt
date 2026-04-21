# ============================================================================
# FlightData Module
# Flight history database, telemetry persistence, and fleet analytics
# ============================================================================

target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        FlightDataModels.h
        FlightDatabaseWorker.h
        FlightDatabaseWorker.cc
        FlightDatabase.h
        FlightDatabase.cc
        FlightDataQueryModel.h
        FlightDataQueryModel.cc
        TelemetryCollector.h
        TelemetryCollector.cc
)

target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)
