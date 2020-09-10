xterm \
  -bg rgb:11/05/4A \
  -fg white \
  -geometry 80x32 \
  -fn 10x20 \
  -title Minicom \
  -name Minicom \
  -class Minicom \
  -n minicom \
  -e "minicom -C /home/mirek/projects/pomiar_temperatury/serial_output.data -S /home/mirek/projects/pomiar_temperatury/get_temp --device=/dev/ttyUSB0"
