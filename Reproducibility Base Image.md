## Reproducibility — Base Image Dependency

**Strategy:** Pinned Ubuntu 24.04 cloud image with SHA256 verification.

The rebuild pipeline downloads the Ubuntu base image from its official upstream source and verifies its SHA256 against the committed `downloads/base-image.sha256.lock`.

### Known limitation

- The Ubuntu image itself is not committed to Git or retained in a separate artifact repository.
- Reproduction depends on the original image remaining available from upstream or another trustworthy source.
- Ubuntu may replace or remove older image builds.
- If the downloaded image differs from the pinned checksum, the rebuild must fail rather than silently accept a newer image.
- Matching the base-image checksum does not guarantee bit-for-bit identical final VM disks, because other build dependencies and runtime-generated data may vary.

### Image upgrade policy

An intentional upgrade may be performed by:

1. Selecting a newer official Ubuntu cloud image.
2. Obtaining and validating its checksum.
3. Updating the checksum lock and image reference.
4. Running the complete Stage 0B verification suite.
5. Committing the updated configuration and checksum together.

**Decision:** For the current Inception-of-Things project, upstream image availability is considered an acceptable dependency. No separate artifact archive is maintained.

**Future review:** Reconsider image retention if builds become long-lived, upstream availability changes, or stronger reproducibility guarantees are required.
