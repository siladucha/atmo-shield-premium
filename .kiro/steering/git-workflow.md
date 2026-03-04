# Git Workflow Rules

## Core Principles

### NO MERGE POLICY
- **NEVER use git merge** - this is a strict rule
- All integration must be done through cherry-pick or rebase
- Maintain clean, linear history without merge commits

### Branch Strategy
- `main` - production releases only
- `develop` - current development version
- `release/x.x.x` - release preparation branches
- `feature/name` - individual features
- `hotfix/x.x.x` - critical fixes for production

## Ukrainian Language Implementation - APPROVED STRATEGY

### Dual-Track Approach
1. **Prepare universal Ukrainian patch**
   - Create complete localization that works for both 1.4.1 and 1.5.1
   - Test patch independently
   - Ensure compatibility across versions

2. **Apply to both branches simultaneously**
   - **Production**: 1.4.1 → 1.4.2 (immediate release)
   - **Development**: Apply to 1.5.1 (continue Health integration)

3. **No cherry-pick needed**
   - Same patch applied to both branches
   - Clean implementation without merge conflicts
   - Maintains version consistency

### Rationale
- Users get Ukrainian support immediately
- Development timeline unaffected
- Single patch ensures quality consistency
- No integration delays for Health features

## Integration Rules
- Use `git cherry-pick` to move specific commits between branches
- Use `git rebase` for branch updates
- Keep commit history clean and linear
- Each commit should be atomic and well-documented

## Release Process
1. Create release branch from develop
2. Test and stabilize
3. Tag and release
4. Cherry-pick critical fixes back to develop if needed
5. Continue development on develop branch

## Emergency Fixes
- Always branch from production tag
- Apply minimal changes
- Release as patch version
- Cherry-pick to develop after release