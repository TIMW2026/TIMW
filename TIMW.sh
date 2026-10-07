#!/bin/bash

mkdir -p PKG
sudo pacman -Syu
arch-nspawn /home/timw/chroot/root pacman -Syu

cd 1.llvm-git/
makechrootpkg -c -r /home/timw/chroot
mv *.pkg.tar.zst ../2.rust-git/

cd ../2.rust-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst 
mv *.pkg.tar.zst ../3.rust-bindgen-git/

cd ../3.rust-bindgen-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst
mv *.pkg.tar.zst ../4.spirv-headers-git/

cd ../4.spirv-headers-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst
mv *.pkg.tar.zst ../5.spirv-tools-git/

cd ../5.spirv-tools-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst
mv *.pkg.tar.zst ../6.spirv-llvm-translator-git/

cd ../6.spirv-llvm-translator-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst
mv *.pkg.tar.zst ../7.libclc-git/

cd ../7.libclc-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst
mv *.pkg.tar.zst ../8.mesa-git/

cd ../8.mesa-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst
mv *.pkg.tar.zst ../9.linux-firmware-git/

cd ../9.linux-firmware-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst
mv *.pkg.tar.zst ../10.linux-mainline/

cd ../10.linux-mainline/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst -I linux-firmware-git*.pkg.tar.zst
mv *.pkg.tar.zst ../11.wine-staging-git/

cd ../11.wine-staging-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst
mv *.pkg.tar.zst ../12.dxvk-mingw-git/

cd ../12.dxvk-mingw-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst wine-staging-git*.pkg.tar.zst
mv *.pkg.tar.zst ../13.vkd3d-proton-mingw-git/

cd ../13.vkd3d-proton-mingw-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst -I wine-staging-git*.pkg.tar.zst -I dxvk-mingw-git*.pkg.tar.zst
mv *.pkg.tar.zst ../14.kodi-gles-git/

cd ../14.kodi-gles-git/
makechrootpkg -c -r /home/timw/chroot -I llvm-git*.pkg.tar.zst -I rust-git*.pkg.tar.zst -I rust-bindgen-git*.pkg.tar.zst -I spirv-headers-git*.pkg.tar.zst -I spirv-tools-git*.pkg.tar.zst -I spirv-llvm-translator-git*.pkg.tar.zst -I libclc-git*.pkg.tar.zst -I mesa-git*.pkg.tar.zst
mv *.pkg.tar.zst ../PKG/