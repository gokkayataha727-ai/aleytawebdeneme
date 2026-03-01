#!/bin/bash

# Download and install Flutter SDK
git clone https://github.com/flutter/flutter.git -b 3.19.6
export PATH="$PATH:`pwd`/flutter/bin"

# Build web project
flutter config --enable-web
flutter pub get
flutter build web --release

