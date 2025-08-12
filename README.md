> **Note:** This is a personal project that is ongoing.
>
> *And yes, I did use AI as the tool that it is for some parts. Cast no stones*

---

# Pixel Lights Controller

A Flutter mobile application for controlling ESP32-based LED pixel strips over Bluetooth Low Energy (BLE).

This application allows users to scan for compatible BLE devices, establish a connection, and send commands to control various LED patterns, colors, and brightness levels in real-time.

## Associated Firmware

This mobile application is designed to work with a specific ESP32 firmware project. You can find the corresponding firmware here:

*   **ESP32 Pixel Node Firmware:** [esp32-pixel-node](https://github.com/insomnolence/esp32-pixel-node)

---

## Features

*   **BLE Device Scanning:** Automatically scans for nearby ESP32 devices advertising the correct service UUID.
*   **Real-time Control:** Send pattern, color, speed, and brightness commands instantly.
*   **Preset Patterns:** A collection of pre-programmed patterns like Rainbow, Sparkle, and March.
*   **Manual Adjustment:** Use a color wheel and sliders to fine-tune the LED output.
*   **Connection Status:** Monitor the connection quality and status with the target device.

## Screenshots

*(Add screenshots of the application here to showcase the UI.)*

---

## Getting Started

Follow these instructions to get a copy of the project up and running on your local machine for development and testing purposes.

### 1. Prerequisites

Make sure you have the Flutter SDK installed on your machine.

*   **Install Flutter:** Follow the official guide at [flutter.dev](https://flutter.dev/docs/get-started/install).

After installation, run the following command to verify your setup. It will also help you install any other required dependencies for your target platform (like Xcode or the Android SDK).

```sh
flutter doctor
```

### 2. Clone the Repository

```sh
git clone <your-repository-url>
cd pixel_lights
```

### 3. Install Dependencies

Once you have the project cloned, you need to fetch the project's dependencies.

```sh
flutter pub get
```

### 4. Platform-Specific Setup

*   **iOS (on macOS only):**
    The iOS project uses CocoaPods to manage native dependencies. Navigate to the `ios` directory and run:
    ```sh
    cd ios
    pod install
    cd ..
    ```

*   **Android:**
    No special setup is usually required.

## Running the Application

1.  **Connect a Device:** Make sure you have a physical device connected or an emulator (Android) / simulator (iOS) running.
2.  **Run the App:** From the root of the project directory, run the following command:

    ```sh
    flutter run
    ```

This will build and install the application on your target device.
