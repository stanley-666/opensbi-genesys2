#!/usr/bin/bash
set -e
OPENSBI_DIR=~/opensbi
cd $OPENSBI_DIR
make distclean
make PLATFORM=generic \
    CROSS_COMPILE=riscv64-linux-gnu- \
    FW_PAYLOAD_PATH=~/u-boot/u-boot-dtb.bin \
    -j16
echo "OpenSBI build completed."
strings build/platform/generic/firmware/fw_payload.elf | grep chipyard

cp ~/opensbi/build/platform/generic/firmware/fw_payload.bin ~/u-boot/u-boot-sbi.bin
riscv64-linux-gnu-objdump -h  ~/opensbi/build/platform/generic/firmware/fw_payload.elf | grep dtb
echo "You can now use this binary with your RISC-V platform."
cd -
echo "Returning to the previous directory."
echo "Script execution finished."