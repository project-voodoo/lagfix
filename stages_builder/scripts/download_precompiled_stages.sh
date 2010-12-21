#!/bin/sh

# delete current stages
rm -v stages/stage1.tar
rm -v stages/stage2.tar.lzma
rm -v stages/stage3-sound.tar.lzma

# download precompiled stages

cd stages
wget http://dl.project-voodoo.org/precompiled/stages/stage1.tar
wget http://dl.project-voodoo.org/precompiled/stages/stage2.tar.lzma
wget http://dl.project-voodoo.org/precompiled/stages/stage3-sound.tar.lzma
