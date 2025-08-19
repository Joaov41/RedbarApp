# RedbarApp 🔴

A macOS menu bar application for browsing Reddit. Features comments summarization and Q&A. Open ai powered text-to-speech functionality as well as local TTS.  Stay updated with your favorite subreddits without leaving your workflow.

<p align="center">
  <img src="ewe.png" alt="RedbarApp Logo" width="200"/>
</p>


![CleanShot 2025-08-19 at 19 18 34@2x](https://github.com/user-attachments/assets/f3c095ce-a4e2-490d-9598-c299d0a24f8d)

![CleanShot 2025-08-19 at 19 18 23@2x](https://github.com/user-attachments/assets/8ee631d2-7869-42f0-b431-580466a272a9)

![CleanShot 2025-08-19 at 19 18 00@2x](https://github.com/user-attachments/assets/f2678af0-1c7d-44cf-acd8-4992f1c25ef1)

![CleanShot 2025-08-19 at 19 17 39@2x](https://github.com/user-attachments/assets/1491aee8-fa1a-4d3e-b3d5-92cd16afed9f)

## ✨ Features

### 🔊 AI-Powered Text-to-Speech
- **OpenAI Integration**: High-quality text-to-speech using OpenAI's advanced TTS API
- **Multiple Voices**: Choose from 6 different voice options (Alloy, Echo, Fable, Onyx, Nova, Shimmer)
- **Smart Chunking**: Intelligent text processing for immediate playback with seamless transitions
- **Performance Optimized**: Concurrent processing and adaptive performance based on network conditions
- **Fallback Support**: Local macOS TTS as s free option 

### 📱 Menu Bar Integration
- **Lightweight**: Unobtrusive menu bar presence that stays out of your way
- **Quick Access**: Instant Reddit browsing without opening a browser
- **Native macOS**: Built with SwiftUI for optimal performance and system integration

### 🖼️ Rich Media Experience
- **Image Gallery**: Beautiful full-screen image viewer with liquid glass effects
- **GIF Support**: Smooth animated GIF playback
- **High Resolution**: Support for high-quality image viewing
- **Kingfisher Integration**: Efficient image loading and caching

### 🔐 Secure Authentication
- **OAuth Integration**: Safe Reddit authentication using OAuth 2.0 with user's own Reddit credentials
- **Keychain Storage**: Secure credential storage using macOS Keychain
- **API Key Management**: Secure storage for OpenAI and other API keys
- **Privacy First**: No credentials stored in plain text

### ⚡ Performance & Caching
- **Memory Caching**: Fast access to recently viewed content
- **Disk Caching**: Persistent storage for frequently accessed data
- **Smart Pre-loading**: Anticipates user needs for smoother experience
- **Concurrent Processing**: Multiple simultaneous operations for speed

### 🎨 Modern Glass UI
- **Liquid Glass Effects**: Modern, translucent background effects
- **Dark Mode Support**: Seamless integration with macOS appearance
- **Responsive Design**: Adapts to different screen sizes and resolutions
- **SwiftUI Native**: Modern UI framework for smooth animations and interactions

## 🛠️ Technical Stack

- **Swift & SwiftUI**: Native macOS development
- **AppKit**: Menu bar integration and window management  
- **AVFoundation**: Audio playback and processing
- **Kingfisher**: Advanced image loading and caching
- **OpenAI API**: Text-to-speech synthesis
- **Reddit API**: Content fetching and user authentication
- **Keychain Services**: Secure credential storage

## 🚀 Getting Started

### Prerequisites
- macOS Tahoe beta
- Reddit application credentials
- OpenAI API key

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/Joaov41/RedbarApp.git
   cd RedbarApp
   ```

2. **Open in Xcode**
   ```bash
   open RedbarApp.xcodeproj
   ```

3. **Configure API Keys**
   - Launch the app and open Settings
   - Add your OpenAI API key
   - Configure Reddit OAuth credentials
   - Test connections to ensure everything works

4. **Build and Run**
   - Select your target device
   - Press `Cmd+R` to build and run

## ⚙️ Configuration

### Reddit Setup
1. Create a Reddit application at https://www.reddit.com/prefs/apps
2. Select "script" as application type
3. Note your client ID and client secret
4. Enter these in RedbarApp settings

### OpenAI Setup
1. Get an API key from https://platform.openai.com/api-keys
2. Enter the key in RedbarApp settings
3. Choose your preferred voice from the available options

## 📱 Usage

1. **Menu Bar Access**: Click the RedbarApp icon in your menu bar
2. **Browse Content**: Navigate through Reddit posts and comments
3. **Listen to Posts**: Click the play button to hear posts read aloud
4. **View Images**: Click on images to view them in full-screen mode
5. **Settings**: Configure API keys, voices, and preferences

## 🎯 Key Components

### Services
- **OpenAIService**: Handles TTS API communication and audio synthesis
- **TTSChunkManager**: Manages text chunking and playback coordination
- **AudioCache**: Provides intelligent caching for audio data
- **RedditAuthManager**: Manages Reddit OAuth authentication
- **KeychainService**: Secure storage for sensitive data

### Views
- **SettingsView**: Configuration interface for API keys and preferences
- **FullScreenImageView**: Immersive image and GIF viewer
- **LiquidGlassBackground**: Beautiful translucent background effects

## 🔧 Architecture

RedbarApp follows a clean architecture pattern:

- **Data Layer**: API services and caching
- **Business Logic**: Managers for authentication, TTS, and media
- **Presentation Layer**: SwiftUI views and view models
- **Platform Integration**: AppKit for menu bar and system integration

## 🤝 Contributing

Contributions are welcome! Please feel free to submit issues, fork the repository, and create pull requests.

1. Fork the project
2. Create your feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Open a Pull Request

## 📄 License

This project is open source. See the repository for license details.

## 🙏 Acknowledgments

- OpenAI for their excellent TTS API
- Reddit for their comprehensive API
- The Swift and SwiftUI community
- Kingfisher team for excellent image handling

## 📞 Support

If you encounter any issues or have questions:
- Open an issue on GitHub
- Check the existing documentation
- Review the configuration steps

---

**RedbarApp** - Bringing Reddit to your menu bar with the power of AI 🚀
