# Changelog

All notable changes to this project will be documented in this file.

## [2.1.0] - 2024-05-20
[![Version](https://img.shields.io/badge/Version-v2.1.0-blue)](https://github.com/ZephyrNULL/care_cube-flutter)
[![Build](https://img.shields.io/badge/Build-Passing-brightgreen)](https://github.com/ZephyrNULL/care_cube-flutter)

### Added
- **Cloud Profile Synchronization**: Full integration with Supabase for real-time backup and syncing of user profile data.
- **Enhanced Profile Editing**: Users can now edit phone numbers, date of birth, gender, blood group, weight, height, address, and more.
- **Health & Emergency Data**: Dedicated sections for allergies, medical conditions, caregiver details, and emergency contacts are now functional and synchronized.
- **Improved Authentication**: Custom error handling for duplicate email registrations, guiding existing users to the sign-in screen.

### Fixed
- Fixed UI responsiveness issues in the Edit Profile screen.
- Improved loading state handling during cloud data retrieval.

## [2.0.0] - 2024-05-20

### Added
- **Expanded Hardware Support**: Increased compartment monitoring from 2 to 4 cups.
- **Improved UI Layout**: The "Live Compartment Status" now features a dual-row grid for better visibility of all 4 cups.
- **Extended MQTT Integration**: Added support for reading and processing sensor data from 2 additional ultrasonic/infrared sensors.
- **Enhanced Status Summary**: The Care Cube Status section now provides a comprehensive overview of all 4 medicine compartments.
- **Full Compartment Mapping**: Users can now assign medicines to Cup 3 and Cup 4 in the scheduling dialog.

### Fixed
- Improved logic for handling null/demo data in the compartment status view.
- Adjusted layout spacing for better readability on smaller mobile screens.
