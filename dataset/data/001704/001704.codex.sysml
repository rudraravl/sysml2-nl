package GoogleCastStreamingSystemModel {

  import ScalarValues::*;
  import SI::*;

  attribute def Percent :> Real;
  attribute def Millisecond :> Real;
  attribute def MegabitPerSecond :> Real;
  attribute def Hertz :> Real;
  attribute def PixelCount :> Integer;
  attribute def CodecName :> String;
  attribute def Uri :> String;

  enum def CastSessionState {
    enum idle;
    enum discovering;
    enum pairing;
    enum connected;
    enum launchingReceiver;
    enum streaming;
    enum paused;
    enum buffering;
    enum terminating;
    enum error;
  }

  enum def MediaCommandKind {
    enum play;
    enum pause;
    enum seek;
    enum stop;
    enum setVolume;
    enum loadMedia;
  }

  item def MediaDescriptor {
    attribute contentUri : Uri;
    attribute title : String;
    attribute durationMs : Millisecond;
    attribute videoCodec : CodecName;
    attribute audioCodec : CodecName;
    attribute nominalBitrate : MegabitPerSecond;
    attribute widthPixels : PixelCount;
    attribute heightPixels : PixelCount;
    attribute frameRate : Hertz;
  }

  item def CastDiscoveryAdvertisement {
    attribute deviceName : String;
    attribute receiverId : String;
    attribute supportsVideo : Boolean;
    attribute supportsAudio : Boolean;
    attribute secureTransportAvailable : Boolean;
  }

  item def SessionControlMessage {
    attribute sessionId : String;
    attribute command : MediaCommandKind;
    attribute targetPositionMs : Millisecond;
    attribute requestedVolume : Percent;
  }

  item def StreamSegment {
    attribute sequenceNumber : Integer;
    attribute mediaTimeStartMs : Millisecond;
    attribute durationMs : Millisecond;
    attribute encrypted : Boolean;
    attribute bitrate : MegabitPerSecond;
  }

  item def PlaybackStatus {
    attribute sessionState : CastSessionState;
    attribute currentPositionMs : Millisecond;
    attribute bufferedAheadMs : Millisecond;
    attribute volume : Percent;
    attribute muted : Boolean;
    attribute errorText : String;
  }

  port def DiscoveryTxPort {
    out item advertisement : CastDiscoveryAdvertisement;
  }

  port def DiscoveryRxPort {
    in item advertisement : CastDiscoveryAdvertisement;
  }

  port def ControlClientPort {
    out item command : SessionControlMessage;
    in item status : PlaybackStatus;
  }

  port def ControlReceiverPort {
    in item command : SessionControlMessage;
    out item status : PlaybackStatus;
  }

  port def MediaRequestPort {
    out item media : MediaDescriptor;
    out item command : SessionControlMessage;
  }

  port def MediaProviderPort {
    in item media : MediaDescriptor;
    out item segment : StreamSegment;
  }

  port def SegmentInputPort {
    in item segment : StreamSegment;
  }

  port def AudioVideoOutputPort {
    out item status : PlaybackStatus;
  }

  part def SenderDevice {
    attribute deviceName : String;
    attribute batteryLevel : Percent;
    attribute localNetworkConnected : Boolean;

    port discoveryIn : DiscoveryRxPort;
    port control : ControlClientPort;
    port mediaRequest : MediaRequestPort;

    part castClient : CastClientApplication;
  }

  part def CastClientApplication {
    attribute selectedReceiverId : String;
    attribute activeSessionId : String;
    attribute requestedStartPositionMs : Millisecond;

    action discoverReceivers {
      in item advertisement : CastDiscoveryAdvertisement;
      out attribute selectedReceiverId : String;
    }

    action startCastSession {
      in attribute receiverId : String;
      out attribute sessionId : String;
    }

    action sendPlaybackCommand {
      in item command : SessionControlMessage;
    }
  }

  part def CastReceiverDevice {
    attribute receiverId : String;
    attribute displayName : String;
    attribute networkSignalStrength : Percent;
    attribute maximumVideoWidth : PixelCount;
    attribute maximumVideoHeight : PixelCount;

    port discoveryOut : DiscoveryTxPort;
    port control : ControlReceiverPort;
    port segmentIn : SegmentInputPort;
    port avOut : AudioVideoOutputPort;

    part receiverRuntime : CastReceiverRuntime;
    part mediaPipeline : MediaPlaybackPipeline;
  }

  part def CastReceiverRuntime {
    attribute currentSessionId : String;
    attribute installedReceiverAppId : String;
    attribute activeState : CastSessionState;

    state machine sessionLifecycle {
      state idle;
      state discovering;
      state pairing;
      state connected;
      state launchingReceiver;
      state streaming;
      state paused;
      state buffering;
      state terminating;
      state error;

      entry; then idle;

      transition idle_to_discovering
        first idle
        then discovering;

      transition discovering_to_pairing
        first discovering
        accept CastDiscoveryAdvertisement
        then pairing;

      transition pairing_to_connected
        first pairing
        then connected;

      transition connected_to_launching
        first connected
        accept SessionControlMessage
        if command == MediaCommandKind::loadMedia
        then launchingReceiver;

      transition launching_to_streaming
        first launchingReceiver
        then streaming;

      transition streaming_to_paused
        first streaming
        accept SessionControlMessage
        if command == MediaCommandKind::pause
        then paused;

      transition paused_to_streaming
        first paused
        accept SessionControlMessage
        if command == MediaCommandKind::play
        then streaming;

      transition streaming_to_buffering
        first streaming
        if mediaPipeline.bufferedAheadMs < 1500.0
        then buffering;

      transition buffering_to_streaming
        first buffering
        if mediaPipeline.bufferedAheadMs >= 5000.0
        then streaming;

      transition streaming_to_terminating
        first streaming
        accept SessionControlMessage
        if command == MediaCommandKind::stop
        then terminating;

      transition paused_to_terminating
        first paused
        accept SessionControlMessage
        if command == MediaCommandKind::stop
        then terminating;

      transition terminating_to_idle
        first terminating
        then idle;

      transition any_to_error
        first idle, discovering, pairing, connected, launchingReceiver, streaming, paused, buffering, terminating
        if networkSignalStrength < 5.0
        then error;
    }
  }

  part def MediaPlaybackPipeline {
    attribute targetLatencyMs : Millisecond = 2000.0;
    attribute bufferedAheadMs : Millisecond;
    attribute currentPlaybackPositionMs : Millisecond;
    attribute decodedVideoFrameRate : Hertz;
    attribute outputVolume : Percent;
    attribute muted : Boolean;

    action requestMediaSegments {
      in item media : MediaDescriptor;
      out item segment : StreamSegment;
    }

    action decodeAudioVideo {
      in item segment : StreamSegment;
      out attribute decodedVideoFrameRate : Hertz;
    }

    action renderToDisplayAndSpeakers {
      in attribute positionMs : Millisecond;
      out item status : PlaybackStatus;
    }
  }

  part def CloudMediaService {
    attribute serviceName : String;
    attribute averageSegmentDurationMs : Millisecond = 4000.0;
    attribute maximumSupportedBitrate : MegabitPerSecond = 25.0;

    port mediaProvider : MediaProviderPort;

    action provideAdaptiveSegment {
      in item media : MediaDescriptor;
      out item segment : StreamSegment;
    }
  }

  part def LocalNetwork {
    attribute ssid : String;
    attribute availableBandwidth : MegabitPerSecond;
    attribute roundTripLatencyMs : Millisecond;
    attribute packetLossPercent : Percent;

    port senderDiscovery : DiscoveryTxPort;
    port receiverDiscovery : DiscoveryRxPort;
    port senderControl : ControlClientPort;
    port receiverControl : ControlReceiverPort;
  }

  part def DisplayAndSpeakerSystem {
    attribute screenWidthPixels : PixelCount;
    attribute screenHeightPixels : PixelCount;
    attribute audioChannels : Integer;
    attribute refreshRate : Hertz;

    port avStatusIn : AudioVideoOutputPort;
  }

  part googleCastSystem {
    attribute primaryFunction : String =
      "Enable a sender device to discover a compatible receiver, establish a controlled cast session, and cause the receiver to fetch, decode, and play cloud-hosted media on a display and speaker system while the sender remains the remote control.";

    part sender : SenderDevice {
      attribute deviceName = "Mobile Sender";
      attribute batteryLevel = 82.0;
      attribute localNetworkConnected = true;
    }

    part receiver : CastReceiverDevice {
      attribute receiverId = "living-room-cast-receiver";
      attribute displayName = "Living Room TV";
      attribute networkSignalStrength = 91.0;
      attribute maximumVideoWidth = 3840;
      attribute maximumVideoHeight = 2160;
    }

    part mediaService : CloudMediaService {
      attribute serviceName = "Example Streaming Origin";
    }

    part network : LocalNetwork {
      attribute ssid = "Home-WiFi";
      attribute availableBandwidth = 80.0;
      attribute roundTripLatencyMs = 24.0;
      attribute packetLossPercent = 0.2;
    }

    part displayAndSpeakers : DisplayAndSpeakerSystem {
      attribute screenWidthPixels = 3840;
      attribute screenHeightPixels = 2160;
      attribute audioChannels = 6;
      attribute refreshRate = 60.0;
    }

    connect receiver.discoveryOut to sender.discoveryIn;
    connect sender.control to receiver.control;
    connect sender.mediaRequest to mediaService.mediaProvider;
    connect mediaService.mediaProvider to receiver.segmentIn;
    connect receiver.avOut to displayAndSpeakers.avStatusIn;
  }

  requirement def PrimaryCastFunctionRequirement {
    doc /* The system shall let a sender select media and direct a receiver to play it, with the receiver obtaining the media stream and producing synchronized audio/video output. */
    subject castSystem :> googleCastSystem;
    require constraint {
      castSystem.receiver.receiverRuntime.activeState == CastSessionState::streaming implies
      castSystem.receiver.mediaPipeline.bufferedAheadMs >= 0.0
    }
  }

  requirement def DiscoveryRequirement {
    doc /* The receiver shall advertise its identity and media capability on the local network so that sender devices can discover it before session creation. */
    subject receiver : CastReceiverDevice;
    require constraint {
      receiver.discoveryOut.advertisement.supportsVideo == true and
      receiver.discoveryOut.advertisement.secureTransportAvailable == true
    }
  }

  requirement def SenderAsRemoteRequirement {
    doc /* During media playback, the sender shall transmit control commands and receive status updates without carrying the media stream itself. */
    subject sender : SenderDevice;
    require constraint {
      sender.localNetworkConnected == true
    }
  }

  requirement def ReceiverFetchRequirement {
    doc /* The receiver shall fetch stream segments from the media provider after receiving a load media command. */
    subject receiver : CastReceiverDevice;
    require constraint {
      receiver.receiverRuntime.activeState == CastSessionState::streaming implies
      receiver.mediaPipeline.targetLatencyMs <= 3000.0
    }
  }

  requirement def PlaybackQualityRequirement {
    doc /* The playback pipeline shall maintain enough buffered media to reduce interruption during nominal network operation. */
    subject pipeline : MediaPlaybackPipeline;
    require constraint {
      pipeline.bufferedAheadMs >= 1500.0
    }
  }

  requirement def VideoCapabilityRequirement {
    doc /* The receiver shall not accept media with dimensions greater than its advertised maximum video capability. */
    subject receiver : CastReceiverDevice;
    require constraint {
      receiver.maximumVideoWidth >= 1920 and
      receiver.maximumVideoHeight >= 1080
    }
  }

  requirement def ControlLatencyRequirement {
    doc /* The local network shall support responsive playback control for common user commands. */
    subject network : LocalNetwork;
    require constraint {
      network.roundTripLatencyMs <= 100.0 and
      network.packetLossPercent <= 1.0
    }
  }

  requirement def SecureSessionRequirement {
    doc /* Session control and media retrieval shall use secure transport when available from the receiver advertisement. */
    subject advertisement : CastDiscoveryAdvertisement;
    require constraint {
      advertisement.secureTransportAvailable == true
    }
  }

  satisfy PrimaryCastFunctionRequirement by googleCastSystem;
  satisfy DiscoveryRequirement by googleCastSystem.receiver;
  satisfy SenderAsRemoteRequirement by googleCastSystem.sender;
  satisfy ReceiverFetchRequirement by googleCastSystem.receiver;
  satisfy PlaybackQualityRequirement by googleCastSystem.receiver.mediaPipeline;
  satisfy VideoCapabilityRequirement by googleCastSystem.receiver;
  satisfy ControlLatencyRequirement by googleCastSystem.network;
}