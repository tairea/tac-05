# Feature: Dark Mode Toggle

## Feature Description
This feature adds a theme toggle button in the top right corner of the application that allows users to switch between dark mode and light mode. The toggle will persist the user's preference in browser localStorage and provide an enhanced viewing experience for users who prefer darker interfaces, especially in low-light environments. The implementation will use CSS custom properties for seamless theme switching and follow modern web development best practices.

## User Story
As a user of the Natural Language SQL Interface
I want to toggle between dark mode and light mode
So that I can choose a comfortable viewing experience based on my environment and preferences

## Problem Statement
The current application only supports a light color theme, which may cause eye strain for users working in low-light environments or for those who prefer darker interfaces. Users have no way to customize the visual appearance of the application to match their preferences or environmental conditions. This limits accessibility and user comfort during extended usage sessions.

## Solution Statement
Implement a theme toggle button in the top right corner of the application header that switches between dark and light modes. The solution will leverage CSS custom properties (CSS variables) to dynamically update colors throughout the application. The theme preference will be stored in localStorage to persist across browser sessions. The implementation will update all existing CSS color variables and ensure all UI components (query section, results table, modal, buttons, etc.) properly adapt to both themes.

## Relevant Files
Use these files to implement the feature:

- `app/client/index.html` - Contains the main HTML structure where we'll add the toggle button in a new header section
- `app/client/src/style.css` - Contains all CSS including the `:root` color variables that need dark mode variants; will add theme classes and media query support
- `app/client/src/main.ts` - Main TypeScript entry point where we'll add theme initialization and toggle functionality
- `app/client/src/types.d.ts` - TypeScript type definitions where we may need to add theme-related types if necessary

### New Files
- `.claude/commands/e2e/test_dark_mode_toggle.md` - E2E test file to validate the dark mode toggle functionality works correctly

## Implementation Plan

### Phase 1: Foundation
First, we'll update the CSS architecture to support theming by defining dark mode color variables and creating a systematic approach to theme switching. We'll update the `:root` selector to include default (light) theme colors and add a `[data-theme="dark"]` selector with dark mode color overrides. This foundation ensures all color references can be dynamically updated.

### Phase 2: Core Implementation
Next, we'll add the toggle button to the UI by creating a header section in the HTML with a theme toggle button positioned in the top right corner. We'll implement the TypeScript logic to handle theme switching, including reading from localStorage on page load, toggling between themes on button click, and persisting the user's choice. The toggle button will have appropriate icons/labels to indicate the current and target theme state.

### Phase 3: Integration
Finally, we'll ensure all existing UI components properly respond to theme changes by testing every section (query input, results table, modal, buttons, tables list, etc.). We'll add smooth transitions for theme changes and ensure the application respects the user's system preference on first load using the `prefers-color-scheme` media query. We'll create an E2E test to validate the feature works correctly.

## Step by Step Tasks
IMPORTANT: Execute every step in order, top to bottom.

### 1. Update CSS with Dark Mode Variables
- Add `[data-theme="dark"]` selector to `app/client/src/style.css`
- Define dark mode color palette with appropriate contrast ratios:
  - Background colors (darker tones for main bg and surfaces)
  - Text colors (lighter tones for readability)
  - Primary/secondary colors (adjusted for dark backgrounds)
  - Border colors (subtle for dark theme)
  - Success/error colors (adjusted for visibility)
- Ensure all existing CSS rules reference the CSS custom properties (no hardcoded colors)
- Add smooth transitions for theme changes (e.g., `transition: background-color 0.3s, color 0.3s`)

### 2. Create Header Section in HTML
- Add a header container at the top of `app/client/index.html` (before the main container)
- Create a flex layout with the title on the left and toggle button on the right
- Move the h1 title into the header section
- Add a theme toggle button with appropriate ID (`theme-toggle-button`)
- Include icon or text label for the toggle (e.g., "🌙" for dark mode, "☀️" for light mode)

### 3. Implement Theme Toggle Logic
- In `app/client/src/main.ts`, add theme initialization function that runs on DOMContentLoaded
- Detect system preference using `window.matchMedia('(prefers-color-scheme: dark)')` as default
- Check localStorage for saved preference (`localStorage.getItem('theme')`)
- Apply the theme by setting `data-theme` attribute on document root: `document.documentElement.setAttribute('data-theme', theme)`
- Implement toggle function that:
  - Gets current theme from `document.documentElement.getAttribute('data-theme')`
  - Switches to opposite theme
  - Updates the `data-theme` attribute
  - Saves preference to localStorage
  - Updates button icon/label
- Add event listener to toggle button

### 4. Style the Theme Toggle Button
- Add CSS styles for the theme toggle button in `app/client/src/style.css`
- Position the button in the top right corner with appropriate padding
- Style for both light and dark themes
- Add hover effects and transitions
- Ensure button is accessible (proper contrast, focus states)

### 5. Create E2E Test for Dark Mode
- Create `.claude/commands/e2e/test_dark_mode_toggle.md`
- Read `.claude/commands/test_e2e.md` to understand the E2E test format
- Read `.claude/commands/e2e/test_basic_query.md` to see an example structure
- Define test steps that validate:
  - Initial theme detection (system preference or localStorage)
  - Toggle button is visible and clickable
  - Clicking toggle changes the theme (verify CSS properties change)
  - Theme preference persists after page reload
  - Both dark and light modes render correctly
- Include screenshots at each major step (initial load, after toggle, after reload)
- Define success criteria for the test

### 6. Test Theme on All Components
- Manually verify all UI sections display correctly in both themes:
  - Header and toggle button
  - Query input section
  - Query button and Upload Data button
  - Results section (SQL display, results table)
  - Available Tables section (table items, column tags, remove buttons)
  - Upload modal (header, sample buttons, drop zone)
  - Loading states and error messages
  - Success messages
- Adjust any colors that don't meet accessibility standards (contrast ratio)

### 7. Run All Validation Commands
- Execute all validation commands listed below to ensure zero regressions
- Fix any issues that arise from the tests
- Ensure the application builds successfully
- Run the new E2E test to validate dark mode functionality

## Testing Strategy

### Unit Tests
Since the frontend doesn't currently have unit tests, we'll rely on:
- TypeScript compilation to catch type errors
- Manual testing of theme toggle functionality
- E2E tests for comprehensive feature validation

### Edge Cases
Test these scenarios:
1. **First-time user**: Should respect system preference (prefers-color-scheme)
2. **User with saved preference**: localStorage theme overrides system preference
3. **Theme toggle spam**: Rapidly clicking toggle should work smoothly
4. **Invalid localStorage value**: App should fall back to system preference
5. **System theme changes**: While app is open, should respect saved preference
6. **Modal open during toggle**: Modal should update theme correctly
7. **Results visible during toggle**: Results table should update theme correctly
8. **Cross-browser compatibility**: Test in Chrome, Firefox, Safari
9. **No localStorage support**: Gracefully fall back to system preference or default light theme
10. **Accessibility**: Toggle button must be keyboard accessible and screen-reader friendly

## Acceptance Criteria
- [ ] Toggle button appears in the top right corner of the application
- [ ] Button shows appropriate icon/label for current theme ("🌙" when in light mode, "☀️" when in dark mode)
- [ ] Clicking toggle switches between dark and light modes
- [ ] Theme change is immediate and affects all UI components
- [ ] Theme preference is saved to localStorage
- [ ] Saved theme persists after browser refresh
- [ ] On first visit, app respects system preference (prefers-color-scheme)
- [ ] All text remains readable in both themes (meets WCAG contrast requirements)
- [ ] Smooth transitions occur when switching themes (no jarring flashes)
- [ ] Toggle button is keyboard accessible (can tab to it and press Enter)
- [ ] All existing functionality continues to work in both themes
- [ ] E2E test passes and validates the feature
- [ ] TypeScript compilation succeeds with no errors
- [ ] Frontend build completes successfully

## Validation Commands
Execute every command to validate the feature works correctly with zero regressions.

- Read `.claude/commands/test_e2e.md`, then read and execute the new E2E test `.claude/commands/e2e/test_dark_mode_toggle.md` to validate the dark mode toggle functionality
- `cd app/server && uv run pytest` - Run server tests to validate the feature works with zero regressions
- `cd app/client && bun tsc --noEmit` - Run frontend tests to validate the feature works with zero regressions
- `cd app/client && bun run build` - Run frontend build to validate the feature works with zero regressions

## Notes

### Design Considerations
- Use CSS custom properties for maximum flexibility and maintainability
- Keep color palette consistent with existing brand colors (purple gradient for primary actions)
- Dark mode should not be pure black (#000000) but a softer dark tone (#1a1a2e or similar) to reduce eye strain
- Ensure sufficient contrast ratios for accessibility (WCAG AA minimum: 4.5:1 for text, 3:1 for large text)

### Future Enhancements
- Add system theme auto-sync: listen to changes in system preference and update accordingly (optional)
- Add more theme options beyond dark/light (e.g., high contrast, custom themes)
- Create a settings panel for additional customization options
- Add animation options for theme transitions (fade, slide, instant)

### Technical Decisions
- **CSS Custom Properties over CSS-in-JS**: Simpler, more performant, no additional dependencies
- **localStorage over cookies**: Better for client-side preferences, no server round-trip needed
- **data-theme attribute over class**: More semantic and follows modern practices
- **System preference as default**: Better UX for new users, respects user's OS-level choice
- **No external theme libraries**: Keep the implementation simple and avoid additional bundle size

### Browser Support
This implementation uses:
- CSS custom properties (supported in all modern browsers)
- localStorage (supported in all browsers)
- prefers-color-scheme media query (widely supported)
- No polyfills needed for target browsers (modern evergreen browsers)
