# convert-jp2-to-jpg.sh: converts JPEG 2000 files to
# JPEG format using lossy compression
#
# Copyright (C) 2023 Andrew Bissell
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU Affero General Public License as published
# by the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU Affero General Public License for more details.
#
# You should have received a copy of the GNU Affero General Public License
# along with this program.  If not, see <https://www.gnu.org/licenses/>.

#!/bin/sh

mkdir jpgs
find . -type f | parallel gm convert {} -format JPG {}.jpg
mv *.jpg jpgs/
cd jpgs
for f in $(find . -type f); do mv $f "$(basename $(basename $f .jpg) .jp2).jpg"; done
