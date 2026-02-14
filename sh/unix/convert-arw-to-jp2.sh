# convert-arw-to-jp2.sh: converts .ARW files from Sony cameras to
# JPEG 2000 format with lossless compression
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

mkdir jp2s
find . -type f | parallel gm convert {} -format JP2 -define jp2:rate=1.0 {}.jp2
mv *.jp2 jp2s/
cd jp2s
for f in $(find . -type f); do mv $f "$(basename $(basename $f .jp2) .ARW).jp2"; done
