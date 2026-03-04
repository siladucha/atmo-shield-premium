# Localization Guidelines

## Ukrainian Language Implementation Strategy

### Recommended Approach: Hotfix Release
Based on current situation (stable 1.4.1 in production, 1.5.1 in development):

1. **Create hotfix branch from v1.4.1**
   ```bash
   git checkout v1.4.1
   git checkout -b hotfix/1.4.2-ukrainian
   ```

2. **Add Ukrainian localization files**
   - Create `uk.json` or equivalent translation files
   - Update language selector UI
   - Add Ukrainian to supported languages list
   - Test all UI elements with Ukrainian text

3. **Release as 1.4.2**
   - Minimal risk, maximum user value
   - Fast deployment to production
   - Stable base for translation quality

4. **Cherry-pick to develop**
   ```bash
   git checkout develop
   git cherry-pick <localization-commits>
   ```

### Localization Best Practices

#### File Structure
```
lib/l10n/
├── app_en.arb (English - base)
├── app_uk.arb (Ukrainian - new)
├── app_he.arb (Hebrew - if exists)
└── app_ru.arb (Russian - if exists)
```

#### Translation Quality
- Use native Ukrainian speakers for translation
- Test with longer Ukrainian text (can be 30-40% longer than English)
- Verify right-to-left text handling if needed
- Test on different screen sizes with Ukrainian text

#### Technical Considerations
- Ensure proper UTF-8 encoding for Cyrillic characters
- Test font rendering for Ukrainian characters
- Verify text input and search functionality
- Check date/time formatting for Ukrainian locale

### Implementation Priority
1. **High Priority**: UI labels, buttons, navigation
2. **Medium Priority**: Help text, descriptions
3. **Low Priority**: Legal text, terms of service

### Testing Checklist
- [ ] All UI elements display correctly in Ukrainian
- [ ] Text fits properly in UI components
- [ ] Input fields accept Ukrainian characters
- [ ] Search works with Cyrillic text
- [ ] Date/time formats are appropriate
- [ ] App store metadata translated

### Deployment Strategy - APPROVED PLAN

#### Phase 1: Prepare Universal Ukrainian Patch
1. Create complete Ukrainian localization patch
2. Test thoroughly on isolated branch
3. Ensure patch works for both 1.4.1 and 1.5.1 codebases

#### Phase 2: Dual Implementation
1. **Production Track (1.4.1 → 1.4.2)**
   - Apply Ukrainian patch to stable 1.4.1
   - Release 1.4.2 with Ukrainian support
   - Deploy to production immediately
   - Monitor user feedback

2. **Development Track (1.5.1)**
   - Apply same Ukrainian patch to 1.5.1 development
   - Continue Health integration work with Ukrainian already included
   - No delays to Health integration timeline

#### Benefits of This Approach
- Users get Ukrainian support immediately via 1.4.2
- Development continues uninterrupted on 1.5.1
- Single patch ensures consistency between versions
- No merge conflicts or integration issues
- Clean separation of concerns