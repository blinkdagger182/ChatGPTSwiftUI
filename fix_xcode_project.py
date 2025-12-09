#!/usr/bin/env python3
"""
Remove references to deleted PDF drawer files from Xcode project
"""

import re

# Files to remove
files_to_remove = [
    'PDFViewWrapper.swift',
    'PDFDrawerContainer.swift', 
    'RightSideDrawerView.swift',
    'PDFFormFieldsView.swift',
    'PDFManager.swift',
    'SamplePDFTestView.swift',
    'PDFDrawerExampleView.swift'
]

# Read project file
with open('XCAChatGPT.xcodeproj/project.pbxproj', 'r') as f:
    content = f.read()

# Remove lines containing these files
lines = content.split('\n')
filtered_lines = []

for line in lines:
    should_keep = True
    for filename in files_to_remove:
        if filename in line and 'PDFDrawerComponents.swift' not in line:
            should_keep = False
            break
    if should_keep:
        filtered_lines.append(line)

# Write back
with open('XCAChatGPT.xcodeproj/project.pbxproj', 'w') as f:
    f.write('\n'.join(filtered_lines))

print("✅ Removed references to deleted files from Xcode project")
print("Now run: Clean Build Folder (Cmd+Shift+K) and Build (Cmd+B)")
