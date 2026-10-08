#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/../.."
if [ "$#" -ne 2 ]; then echo 'Usage: run_native.sh process.rmp result_directory' >&2; exit 2; fi
runtime='/Applications/AI Studio 2026.1.1.app/Contents'
mkdir -p work/native_ai
/usr/bin/javac --release 17 -cp "$runtime/Resources/RapidMiner-Studio/lib/*" -d work/native_ai scripts/rapidminer/NativeProcessRunner.java
"$runtime/Helpers/openjdk.jre/Contents/Home/bin/java" -Djava.awt.headless=true -Xmx2g \
 --add-opens java.base/java.util=ALL-UNNAMED \
 --add-opens java.base/java.lang=ALL-UNNAMED \
 --add-opens java.base/java.io=ALL-UNNAMED \
 --add-opens java.base/java.net=ALL-UNNAMED \
 --add-opens java.base/java.lang.reflect=ALL-UNNAMED \
 --add-opens java.desktop/javax.swing=ALL-UNNAMED \
 --add-opens java.desktop/java.awt=ALL-UNNAMED \
 --add-opens java.sql/java.sql=ALL-UNNAMED \
 -cp "work/native_ai:$runtime/Resources/RapidMiner-Studio/lib/*" NativeProcessRunner "$1" "$2"
