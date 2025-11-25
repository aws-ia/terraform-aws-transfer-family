# Code-Talk Scripts - Refactoring Updates

## Summary
Updated code-talk scripts to reflect the AgentCore refactoring where ECR repositories and Docker builds were moved from Stage 3 to Stage 0.

## Files Updated

### 1. `stage0-deploy.sh`
**Changes:**
- Updated header comment to mention ECR repositories and Docker builds
- Updated title from "Identity Foundation Deployment" to "Identity Foundation + AgentCore ECR"
- Added output section showing ECR repositories created and Docker images built
- Added note that images are ready for Stage 3 agent deployment

**Impact:**
- Users now see that Docker builds happen in Stage 0 (~2 min)
- Clear indication that 5 ECR repos and images are created

### 2. `stage3-deploy.sh`
**Changes:**
- Updated header comment to clarify "Agent Deployment Only"
- Added note: "Docker images were built in Stage 0"
- Updated title from "AI Claims Processing Deployment" to "AI Claims Processing (Agent Deployment)"

**Impact:**
- Users understand Stage 3 is faster because Docker builds already completed
- Clear separation of concerns

### 3. `DEMO-SETUP.md`
**Changes:**
- Updated Stage 0 section title to "Identity Foundation + AgentCore ECR"
- Added bullet point about ECR repositories and Docker images (~2 min build time)
- Updated Stage 0 deployment steps to mention Docker builds
- Updated Stage 3 section title to "AI Claims Processing (Agent Deployment)"
- Added note explaining Docker images come from Stage 0, saving ~2 minutes

**Impact:**
- Documentation accurately reflects the refactored architecture
- Users have correct expectations about deployment times

## Scripts NOT Changed

### `stage0-verify.sh`
- No changes needed - verification logic remains the same
- Still checks Bedrock model access and other prerequisites

### `stage1-deploy.sh`, `stage1-test.sh`
- No changes needed - Stage 1 unaffected by refactoring

### `stage2-deploy.sh`, `stage2-test.sh`
- No changes needed - Stage 2 unaffected by refactoring

### `stage3-test.sh`
- No changes needed - Testing logic remains the same
- Still tests the AI claims processing pipeline

### `demo/` scripts
- No changes needed - Demo scripts don't reference stage deployment process

## Key Messages for Users

1. **Stage 0 now includes Docker builds**: First deployment takes ~2 minutes longer but builds all agent images
2. **Stage 3 is faster**: No Docker builds needed, just agent deployment
3. **Consistent with refactoring**: Scripts match the infrastructure code changes
4. **No workflow changes**: Users still run `./stage0-deploy.sh` then `./stage3-deploy.sh` as before

## Testing Recommendations

Before demo:
1. Run `./stage0-deploy.sh` - verify ECR output shows 5 repositories
2. Check ECR console - confirm 5 images exist with "latest" tag
3. Run `./stage3-deploy.sh` - verify faster deployment (no Docker builds)
4. Run `./stage3-test.sh` - confirm agents work with pre-built images
