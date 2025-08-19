# OpenAI TTS Implementation Guide

This document describes the implementation of Text-to-Speech (TTS) using OpenAI's API with optimized performance and immediate playback.

## Overview

The implementation consists of three main components:
1. `OpenAIService`: Handles API communication and audio synthesis
2. `TTSChunkManager`: Manages text chunking and playback
3. `AudioCache`: Provides memory and disk caching for audio data

## Key Features

- Immediate playback start (1-2 seconds)
- Smart text chunking with sentence preservation
- Concurrent processing of chunks
- Memory and disk caching
- Multiple voice options
- Progress tracking
- Error handling
- Local (macOS) TTS fallback

## Components Detail

### TTSChunkManager

```swift
class TTSChunkManager {
    private let maxChunkSize = 2000 // Reduced for faster processing
    private let initialChunkSize = 200 // Small first chunk for immediate playback
}
```

The chunk manager uses a two-phase approach:
1. Quick first chunk (≤200 chars) for immediate playback
2. Larger chunks (≤2000 chars) for the rest of the text

### OpenAIService

Key improvements:
- Processes first chunk separately for immediate playback
- Handles up to 3 concurrent requests for remaining chunks
- Seamless transition from first chunk to complete audio
- Voice selection support

### AudioCache

Implements a two-level caching strategy:
1. Memory cache (NSCache)
   - 100 items limit
   - 50MB total size limit
2. Disk cache
   - Persistent storage
   - SHA-256 hashed keys

## Usage Example

```swift
// Initialize TTS
let service = OpenAIService.shared

// Start speech synthesis
Task {
    do {
        let player = try await service.synthesizeSpeech(
            text: textToSpeak,
            progressHandler: { progress in
                // Update progress (0.0 to 1.0)
            },
            onFirstChunkReady: { firstChunkPlayer in
                // Start playing immediately
                firstChunkPlayer.play()
            }
        )
        
        // Play complete audio when ready
        player.play()
    } catch {
        // Handle errors
    }
}
```

## Voice Options

Available voices:
- Alloy (Balanced)
- Echo (Warm)
- Fable (Expressive)
- Onyx (Deep)
- Nova (Energetic)
- Shimmer (Clear)

## Performance Optimizations

1. **Quick Start**
   - First chunk processed immediately
   - Looks for natural sentence break within 200 chars
   - Starts playback while rest processes

2. **Concurrent Processing**
   - First chunk: Single request
   - Remaining chunks: Up to 3 concurrent requests
   - Smart progress tracking

3. **Caching**
   - Memory cache for frequent requests
   - Disk cache for persistence
   - Cache includes voice selection

4. **Error Handling**
   - Graceful fallback to local TTS
   - Detailed error messages
   - Network error recovery

## Implementation Flow

1. Text is received for synthesis
2. TTSChunkManager splits text:
   - First small chunk (≤200 chars)
   - Remaining text in larger chunks
3. OpenAIService processes first chunk
4. Immediate playback starts
5. Remaining chunks processed concurrently
6. Seamless transition to complete audio

## Error Handling

The implementation includes comprehensive error handling:
- API key validation
- Network errors
- Invalid responses
- Playback failures
- Cache errors

## Fallback Options

1. **Local TTS**
   - Uses macOS system voices
   - Immediate fallback if cloud fails
   - No internet required

2. **Cached Audio**
   - Uses cached version if available
   - Reduces API calls
   - Faster playback for repeated text

## Best Practices

1. **Text Preparation**
   - Clean text before synthesis
   - Remove unnecessary whitespace
   - Handle special characters

2. **Resource Management**
   - Stop previous playback before new
   - Clear old cache entries
   - Handle memory pressure

3. **User Experience**
   - Show progress indicators
   - Provide voice selection
   - Allow playback control

## API Requirements

- OpenAI API key
- Internet connection
- Support for MP3 format
- AVFoundation framework

## Future Improvements

Potential enhancements:
1. Adaptive chunk sizing based on network
2. Background audio session support
3. Enhanced caching strategies
4. Voice preference persistence
5. Offline mode improvements

## Notes

- API key should be stored securely
- Consider rate limits and costs
- Test with various text lengths
- Monitor memory usage
- Handle background/foreground transitions 