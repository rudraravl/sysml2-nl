package 'Kodi Media Center System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    attribute def MediaFormat;
    attribute def VideoCodec;
    attribute def AudioCodec;
    attribute def UserCommand;
    attribute def PlaybackState;
    
    item def MediaMetadata {
        attribute title : String;
        attribute duration : DurationValue;
        attribute resolution : String;
        attribute format : MediaFormat;
    }
    
    item def MediaContent {
        attribute metadata : MediaMetadata;
        attribute filePath : String;
        attribute fileSize : MassValue;
    }
    
    item def VideoStream {
        attribute resolution : String;
        attribute frameRate : Real;
        attribute bitrate : Real;
    }
    
    item def AudioStream {
        attribute channels : Integer;
        attribute sampleRate : FrequencyValue;
        attribute bitrate : Real;
    }
    
    port def MediaInputPort {
        in item content : MediaContent;
    }
    
    port def VideoOutputPort {
        out item video : VideoStream;
    }
    
    port def AudioOutputPort {
        out item audio : AudioStream;
    }
    
    port def UserControlPort {
        in attribute command : UserCommand;
    }
    
    port def NetworkPort {
        in attribute streamURL : String;
        out item streamData : MediaContent;
    }
    
    part def MediaLibrary {
        attribute mediaCollection : MediaContent[*];
        port libraryAccess : MediaInputPort;
        
        action def ScanMediaSources {
            in sourcePath : String;
            out discoveredMedia : MediaContent[*];
        }
        
        action def IndexMedia {
            in media : MediaContent;
            out indexed : Boolean;
        }
        
        action def RetrieveMedia {
            in searchQuery : String;
            out results : MediaContent[*];
        }
    }
    
    part def MediaDecoder {
        port mediaIn : MediaInputPort;
        port videoOut : VideoOutputPort;
        port audioOut : AudioOutputPort;
        
        action def DecodeVideo {
            in encodedContent : MediaContent;
            out decodedVideo : VideoStream;
        }
        
        action def DecodeAudio {
            in encodedContent : MediaContent;
            out decodedAudio : AudioStream;
        }
    }
    
    part def NetworkStreamer {
        port networkAccess : NetworkPort;
        
        action def StreamFromNetwork {
            in url : String;
            out streamContent : MediaContent;
        }
        
        action def BufferStream {
            in streamData : MediaContent;
            out buffered : Boolean;
        }
    }
    
    part def UserInterface {
        port userControl : UserControlPort;
        
        action def DisplayMenu {
            in menuItems : String[*];
            out selectedItem : String;
        }
        
        action def ProcessUserInput {
            in userInput : UserCommand;
            out action : String;
        }
    }
    
    part def PlaybackController {
        attribute currentMedia : MediaContent;
        attribute playbackPosition : DurationValue;
        attribute currentState : PlaybackState;
        
        action def StartPlayback {
            in media : MediaContent;
            out playing : Boolean;
        }
        
        action def PausePlayback {
            out paused : Boolean;
        }
        
        action def StopPlayback {
            out stopped : Boolean;
        }
        
        action def SeekPosition {
            in targetPosition : DurationValue;
            out newPosition : DurationValue;
        }
    }
    
    part def DisplayDevice {
        port videoIn : VideoOutputPort;
        
        action def RenderVideo {
            in videoStream : VideoStream;
            out displayed : Boolean;
        }
    }
    
    part def AudioDevice {
        port audioIn : AudioOutputPort;
        
        action def PlayAudio {
            in audioStream : AudioStream;
            out played : Boolean;
        }
    }
    
    action def ManageMediaPlayback {
        in userCommand : UserCommand;
        in selectedMedia : MediaContent;
        out videoOutput : VideoStream;
        out audioOutput : AudioStream;
        
        first start;
        then merge awaitCommand;
        
        then action receiveCommand {
            in cmd = userCommand;
            out command : UserCommand;
        }
        
        then decide;
            if receiveCommand.command == "play" then loadAndDecode;
            if receiveCommand.command == "pause" then pausePlayback;
            if receiveCommand.command == "stop" then stopPlayback;
            if receiveCommand.command == "seek" then seekPosition;
        
        action loadAndDecode {
            in media = selectedMedia;
            out video = videoOutput;
            out audio = audioOutput;
        }
        then streamOutput;
        
        action streamOutput {
            in video : VideoStream;
            in audio : AudioStream;
        }
        then awaitCommand;
        
        action pausePlayback {
            out paused : Boolean;
        }
        then awaitCommand;
        
        action stopPlayback {
            out stopped : Boolean;
        }
        then done;
        
        action seekPosition {
            in position : DurationValue;
            out newPosition : DurationValue;
        }
        then awaitCommand;
    }
    
    part def KodiSystem {
        doc /* Kodi Media Center system definition. */
    }
    
    part kodiMediaCenter : KodiSystem {
        doc /* 
            Kodi is an open-source media center application that provides a unified 
            interface for discovering, organizing, and playing multimedia content 
            from local storage, network shares, and internet streaming services.
        */
        
        part library : MediaLibrary {
            perform kodiMediaCenter.organizeMediaLibrary;
        }
        
        part decoder : MediaDecoder {
            perform kodiMediaCenter.playMediaContent.decode;
        }
        
        part streamer : NetworkStreamer {
            perform kodiMediaCenter.streamNetworkContent;
        }
        
        part ui : UserInterface {
            perform kodiMediaCenter.handleUserInteraction;
        }
        
        part playback : PlaybackController {
            perform kodiMediaCenter.playMediaContent.control;
        }
        
        part display : DisplayDevice;
        part speakers : AudioDevice;
        
        connection connect library.libraryAccess to decoder.mediaIn;
        connection connect decoder.videoOut to display.videoIn;
        connection connect decoder.audioOut to speakers.audioIn;
        
        action organizeMediaLibrary {
            first start;
            then action scanSources {
                out mediaSources : String[*];
            }
            then action indexContent {
                in sources = scanSources.mediaSources;
                out indexed : Boolean;
            }
            then action updateMetadata {
                out updated : Boolean;
            }
            then done;
        }
        
        action streamNetworkContent {
            in streamURL : String;
            out streamContent : MediaContent;
            
            first start;
            then action connectToSource {
                in url = streamURL;
                out connected : Boolean;
            }
            then action bufferStream {
                out buffered : Boolean;
            }
            then action deliverStream {
                out content = streamContent;
            }
            then done;
        }
        
        action handleUserInteraction {
            first start;
            then merge waitForInput;
            
            then action receiveInput {
                out command : UserCommand;
            }
            
            then decide;
                if receiveInput.command == "browse" then browseLibrary;
                if receiveInput.command == "search" then searchMedia;
                if receiveInput.command == "play" then initiatePlayback;
                if receiveInput.command == "exit" then exitSystem;
            
            action browseLibrary {
                out displayContent : String;
            }
            then waitForInput;
            
            action searchMedia {
                in query : String;
                out results : MediaContent[*];
            }
            then waitForInput;
            
            action initiatePlayback {
                out playbackStarted : Boolean;
            }
            then waitForInput;
            
            action exitSystem {
                out shutdown : Boolean;
            }
            then done;
        }
        
        action playMediaContent references ManageMediaPlayback {
            first start;
            then action selectMedia {
                out selected : MediaContent;
            }
            then action decode {
                in media = selectMedia.selected;
                out video : VideoStream;
                out audio : AudioStream;
            }
            then action control {
                in videoStream = decode.video;
                in audioStream = decode.audio;
            }
            then merge monitorPlayback;
            
            then action checkStatus {
                out status : PlaybackState;
            }
            
            then decide;
                if checkStatus.status == "playing" then monitorPlayback;
                if checkStatus.status == "ended" then endPlayback;
                if checkStatus.status == "error" then handleError;
            
            action handleError {
                out errorHandled : Boolean;
            }
            then endPlayback;
            
            action endPlayback;
            then done;
        }
        
        perform action providePrimaryFunction {
            doc /* 
                The primary function of Kodi is to aggregate multimedia content from 
                diverse sources (local files, network shares, streaming services), 
                organize it in a searchable library, decode the content, and deliver 
                synchronized audio and video streams to connected output devices, 
                all controlled through an intuitive user interface.
            */
            
            first start;
            then action initializeSystem {
                out initialized : Boolean;
            }
            then merge operatingLoop;
            
            then action processUserRequest {
                out requestType : String;
            }
            
            then decide;
                if processUserRequest.requestType == "playback" then executePlayback;
                if processUserRequest.requestType == "library" then manageLibrary;
                if processUserRequest.requestType == "stream" then handleStreaming;
                if processUserRequest.requestType == "shutdown" then shutdownSystem;
            
            action executePlayback references playMediaContent;
            then operatingLoop;
            
            action manageLibrary references organizeMediaLibrary;
            then operatingLoop;
            
            action handleStreaming references streamNetworkContent;
            then operatingLoop;
            
            action shutdownSystem {
                out cleanShutdown : Boolean;
            }
            then done;
        }
    }
    
    requirement def MediaPlaybackRequirement {
        doc /* The system shall decode and play media content in multiple formats. */
        subject kodi : KodiSystem;
    }
    
    requirement def LibraryManagementRequirement {
        doc /* The system shall organize and index media content from multiple sources. */
        subject kodi : KodiSystem;
    }
    
    requirement def NetworkStreamingRequirement {
        doc /* The system shall stream media content from network sources. */
        subject kodi : KodiSystem;
    }
    
    requirement def UserInterfaceRequirement {
        doc /* The system shall provide an intuitive interface for media navigation and control. */
        subject kodi : KodiSystem;
    }
    
    requirement kodiSystemRequirements {
        doc /* Top-level requirements for Kodi Media Center system. */
        
        require MediaPlaybackRequirement;
        require LibraryManagementRequirement;
        require NetworkStreamingRequirement;
        require UserInterfaceRequirement;
        
        satisfy MediaPlaybackRequirement by kodiMediaCenter.decoder;
        satisfy LibraryManagementRequirement by kodiMediaCenter.library;
        satisfy NetworkStreamingRequirement by kodiMediaCenter.streamer;
        satisfy UserInterfaceRequirement by kodiMediaCenter.ui;
    }
}

// --- Test harness (auto-generated) ---
package ExecutionHarness {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import 'Kodi Media Center System'::*;

    action orchestrator {
        action actionProbe : ScanMediaSources {
            in sourcePath = "";
        }
        first actionProbe;
    }
}
