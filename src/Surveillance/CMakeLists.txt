# ============================================================================
# Surveillance Module
# Video feeds, surveillance UI, and management logic
# ============================================================================

# C++ sources added directly to the main QGC target
target_sources(${CMAKE_PROJECT_NAME}
    PRIVATE
        SurveillanceManager.cc
        SurveillanceManager.h
        VideoFeedItem.cc
        VideoFeedItem.h
)

# Make headers visible
target_include_directories(${CMAKE_PROJECT_NAME}
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
)

