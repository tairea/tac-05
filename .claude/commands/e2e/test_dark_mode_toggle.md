# E2E Test: Dark Mode Toggle

Test dark mode toggle functionality in the Natural Language SQL Interface application.

## User Story

As a user
I want to toggle between dark mode and light mode
So that I can choose a comfortable viewing experience based on my preferences

## Test Steps

1. Navigate to the `Application URL`
2. Take a screenshot of the initial state (light mode)
3. **Verify** the page title is "Natural Language SQL Interface"
4. **Verify** the theme toggle button is present in the header
5. **Verify** the theme toggle button displays the moon icon (🌙) in light mode
6. **Verify** the current theme is light by checking `document.documentElement.getAttribute('data-theme')` returns 'light' or null
7. **Verify** the background color is the light theme color by checking computed styles

8. Click the theme toggle button
9. Take a screenshot after clicking the toggle button (dark mode)
10. **Verify** the theme toggle button now displays the sun icon (☀️)
11. **Verify** the current theme is dark by checking `document.documentElement.getAttribute('data-theme')` returns 'dark'
12. **Verify** the background color has changed to the dark theme color
13. **Verify** localStorage contains 'theme' = 'dark'

14. Click the theme toggle button again
15. Take a screenshot after clicking the toggle button again (back to light mode)
16. **Verify** the theme toggle button displays the moon icon (🌙) again
17. **Verify** the current theme is light by checking `document.documentElement.getAttribute('data-theme')` returns 'light'
18. **Verify** the background color has changed back to the light theme color
19. **Verify** localStorage contains 'theme' = 'light'

20. Set theme to dark again using the toggle button
21. Reload the page
22. Take a screenshot after page reload
23. **Verify** the theme is still dark after reload (localStorage persistence)
24. **Verify** the theme toggle button still displays the sun icon (☀️)

## Success Criteria
- Theme toggle button is visible and clickable
- Clicking toggle switches between dark and light modes
- Theme icon updates correctly (🌙 in light mode, ☀️ in dark mode)
- Background and text colors change appropriately
- Theme preference is saved to localStorage
- Theme persists after page reload
- All UI components are visible in both themes
- 4 screenshots are taken
