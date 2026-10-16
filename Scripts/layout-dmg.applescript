on run argv
    set volumeName to item 1 of argv
    tell application "Finder"
        tell disk volumeName
            open
            set current view of container window to icon view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {180, 180, 820, 600}
            set options to icon view options of container window
            set arrangement of options to not arranged
            set icon size of options to 100
            set text size of options to 14
            set background picture of options to file ".background:background.png"
            set position of item "DevPet.app" of container window to {170, 215}
            set position of item "Applications" of container window to {470, 215}
            if exists item "Install DevPet.txt" then set position of item "Install DevPet.txt" of container window to {320, 510}
            close
            open
            update without registering applications
            delay 2
            close
        end tell
    end tell
end run
