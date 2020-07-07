import jnim
import streams

type
    AAssetManager* = ptr object
    AAsset* = ptr object
    AAssetDir* = ptr object
    Off_t* = int
    Off64_t* = int64
    AssetOpenMode* {.size: sizeof(cint).} = enum
        AASSET_MODE_UNKNOWN
        AASSET_MODE_RANDOM
        AASSET_MODE_STREAMING
        AASSET_MODE_BUFFER

proc openDir*(mgr: AAssetManager, dirName: cstring): AAssetDir {.importc: "AAssetManager_openDir".}
proc open*(mgr: AAssetManager, fileName: cstring, mode: AssetOpenMode): AAsset {.importc: "AAssetManager_open".}
proc getNextFileName*(assetDir: AAssetDir): cstring {.importc: "AAssetDir_getNextFileName".}
proc rewind*(assetDir: AAssetDir) {.importc: "AAssetDir_rewind".}
proc close*(assetDir: AAssetDir) {.importc: "AAssetDir_close".}
proc read*(asset: AAsset, buf: pointer, count: csize): cint {.importc: "AAsset_read".}
proc seekAux(asset: AAsset, offset: Off_t, whence: cint): Off_t {.importc: "AAsset_seek".}
proc seek64Aux(asset: AAsset, offset: Off64_t, whence: cint): Off64_t {.importc: "AAsset_seek64".}

template seek*(asset: AAsset, offset: Off_t, relativeTo: FileSeekPos): Off_t =
    asset.seekAux(offset, cint(relativeTo))

template seek64*(asset: AAsset, offset: Off64_t, relativeTo: FileSeekPos): Off64_t =
    asset.seek64Aux(offset, cint(relativeTo))


proc close*(asset: AAsset) {.importc: "AAsset_close".}
proc getBuffer*(asset: AAsset): pointer {.importc: "AAsset_getBuffer".}
proc getLength*(asset: AAsset): Off_t {.importc: "AAsset_getLength".}
proc getLength64*(asset: AAsset): Off64_t {.importc: "AAsset_getLength64".}
proc getRemainingLength*(asset: AAsset): Off_t {.importc: "AAsset_getRemainingLength".}
proc getRemainingLength64*(asset: AAsset): Off64_t {.importc: "AAsset_getRemainingLength64".}
proc openFileDescriptor*(asset: AAsset, outStart, outLength: ptr Off_t): cint {.importc: "AAsset_openFileDescriptor".}
proc openFileDescriptor64*(asset: AAsset, outStart, outLength: ptr Off64_t): cint {.importc: "AAsset_openFileDescriptor64".}
proc isAllocated*(asset: AAsset): cint {.importc: "AAsset_isAllocated".}
proc AAssetManager_fromJava*(env: ptr JNIEnv, assetManager: jobject): AAssetManager {.importc.}
proc AAssetManager_fromJava*(assetManager: jobject): AAssetManager {.inline.} = AAssetManager_fromJava(jnim.theEnv, assetManager)


################################################################################
# Stream support
type
    AssetStream = ref object of StreamObj
        asset: AAsset

proc aClose(s: Stream) =
    let s = AssetStream(s)
    if s.asset != nil:
        s.asset.close()
        s.asset = nil

proc aAtEnd(s: Stream): bool =
    let s = AssetStream(s)
    result = s.asset.getLength() == s.asset.seek(0, fspCur)

proc aSetPosition(s: Stream, pos: int) =
    let s = AssetStream(s)
    discard s.asset.seek(pos, fspSet)

proc aGetPosition(s: Stream): int =
    let s = AssetStream(s)
    result = s.asset.seek(0, fspCur).int

proc aReadDataStr(s: Stream, buffer: var string, slice: Slice[int]): int =
    let s = AssetStream(s)
    let size = csize(slice.b + 1 - slice.a)
    result = s.asset.read(addr buffer[slice.a], size).int

proc aReadData(s: Stream, buffer: pointer, bufLen: int): int =
    let s = AssetStream(s)
    result = s.asset.read(buffer, csize(bufLen)).int

proc aPeekData(s: Stream, buffer: pointer, bufLen: int): int =
    let s = AssetStream(s)
    let pos = s.asset.seek(0, fspCur)
    result = s.asset.read(buffer, csize(bufLen)).int
    discard s.asset.seek(pos, fspSet)

proc aWriteData(s: Stream, buffer: pointer, bufLen: int) =
    raise newException(Defect, "Can not write to asset")

proc streamForReading*(am: AAssetManager, path: string): Stream =
    let a = am.open(path, AASSET_MODE_UNKNOWN)
    if not a.isNil:
        var s: AssetStream
        s.new()
        s.asset = a
        s.closeImpl = aClose
        s.atEndImpl = aAtEnd
        s.setPositionImpl = aSetPosition
        s.getPositionImpl = aGetPosition
        s.readDataStrImpl = aReadDataStr
        s.readDataImpl = aReadData
        s.peekDataImpl = aPeekData
        s.writeDataImpl = aWriteData
        result = s
