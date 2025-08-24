#!/usr/bin/env bash
set -e

# ====== 路徑設定 ======
OPENSBI_DIR=~/opensbi
UBOOT_DIR=~/u-boot
LINUX_DIR=~/linux       # 假設 kernel Image 放這裡
DISK=/dev/sdX           # ⚠️ 請改成你的 SD 卡裝置 (例如 /dev/sde)

FW_PAYLOAD=$OPENSBI_DIR/build/platform/generic/firmware/fw_payload.bin
KERNEL=$LINUX_DIR/Image
DTB_SRC=$UBOOT_DIR/arch/riscv/dts/chipyard.fpga.genesys2.GENESYS2FPGATestHarness.RocketGENESYS2Config.dtb
DTB_DST=$OPENSBI_DIR/system.dtb   # 先複製到 opensbi 這邊

MNT=/mnt/sdcard

# ====== 檔案檢查 ======
if [ ! -f "$FW_PAYLOAD" ]; then
  echo "❌ 找不到 fw_payload.bin，請先 build OpenSBI"
  exit 1
fi
if [ ! -f "$KERNEL" ]; then
  echo "❌ 找不到 Linux Image ($KERNEL)"
  exit 1
fi
if [ ! -f "$DTB_SRC" ]; then
  echo "❌ 找不到 U-Boot 產生的 dtb ($DTB_SRC)"
  exit 1
fi

# ====== Step 0. 複製 dtb 到 opensbi ======
echo "[0] 複製 dtb 到 $DTB_DST"
cp $DTB_SRC $DTB_DST

# ====== Step 1. 清除舊 partition table ======
echo "[1] 清除 $DISK 舊資料"
sudo wipefs -a $DISK
sudo dd if=/dev/zero of=$DISK bs=1M count=2 conv=fsync

# ====== Step 2. 寫入 fw_payload.bin 到 sector 34 ======
echo "[2] 燒錄 fw_payload.bin 到 $DISK (sector 34)"
sudo dd if=$FW_PAYLOAD of=$DISK bs=512 seek=34 conv=fsync status=progress

# ====== Step 3. 建立 FAT32 分區 ======
echo "[3] 建立 partition table + FAT32 分區"
sudo parted -s $DISK mklabel msdos
sudo parted -s $DISK mkpart primary fat32 1MiB 100%

PARTITION=${DISK}1
sleep 2

# ====== Step 4. 格式化 FAT32 ======
echo "[4] 格式化 $PARTITION 為 FAT32"
sudo mkfs.vfat -F 32 $PARTITION

# ====== Step 5. 複製 Kernel 與 DTB ======
echo "[5] 複製 kernel Image 與 system.dtb"
echo "[0] 複製 U-Boot dtb 到 OpenSBI ($DTB_DST)"
cp $DTB_SRC $DTB_DST
sudo mkdir -p $MNT
sudo mount $PARTITION $MNT
sudo cp $KERNEL $MNT/Image
sync
sudo umount $MNT

# ====== Step 6. 驗證 ======
echo "[6] 驗證 SD 卡內容"
sudo hexdump -C $DISK | head -n 20
lsblk -f $DISK

echo "🎉 SD 卡準備完成，可以插到 FPGA 開機！"
