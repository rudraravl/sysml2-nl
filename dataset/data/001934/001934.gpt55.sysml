package TelepresenceSystemSpecification {

  import ScalarValues::*;
  import ISQ::*;
  import SI::*;

  unit def ms :> SI::s;
  unit def Mbps;
  unit def fps;
  unit def pixel;
  unit def degree;
  unit def percent;
  unit def dB;
  unit def lux;

  attribute def Latency :> ISQ::time;
  attribute def Jitter :> ISQ::time;
  attribute def Bandwidth;
  attribute def FrameRate;
  attribute def PixelCount :> ScalarValues::Integer;
  attribute def ViewingAngle;
  attribute def Availability :> ScalarValues::Real;
  attribute def AudioLevel;
  attribute def Illumination;
  attribute def Confidence :> ScalarValues::Real;
  attribute def SessionIdentifier :> ScalarValues::String;
  attribute def PersonName :> ScalarValues::String;

  enum def SessionMode {
    enum standard;
    enum immersive;
    enum presentation;
    enum maintenance;
  }

  enum def SessionStateKind {
    enum poweredOff;
    enum idle;
    enum authenticating;
    enum connecting;
    enum negotiatingMedia;
    enum active;
    enum degraded;
    enum reconnecting;
    enum terminating;
    enum faulted;
  }

  enum def NetworkHealthKind {
    enum nominal;
    enum congested;
    enum interrupted;
    enum unavailable;
  }

  enum def SecurityDecisionKind {
    enum allowed;
    enum denied;
    enum expired;
  }

  item def VideoFrame {
    attribute width : PixelCount = 3840 [pixel];
    attribute height : PixelCount = 2160 [pixel];
    attribute frameRate : FrameRate = 60 [fps];
    attribute horizontalFieldOfView : ViewingAngle = 90 [degree];
    attribute captureIllumination : Illumination = 500 [lux];
  }

  item def AudioFrame {
    attribute channels : ScalarValues::Integer = 8;
    attribute sampleRateHz : ScalarValues::Integer = 48000;
    attribute nominalLevel : AudioLevel = 70 [dB];
  }

  item def PresenceTelemetry {
    attribute faceTrackingConfidence : Confidence = 0.95;
    attribute gazeTrackingConfidence : Confidence = 0.90;
    attribute speakerLocalizationConfidence : Confidence = 0.92;
    attribute detectedParticipantCount : ScalarValues::Integer;
  }

  item def ParticipantPresence {
    attribute participantName : PersonName;
    attribute siteName : ScalarValues::String;
    item video : VideoFrame;
    item audio : AudioFrame;
    item telemetry : PresenceTelemetry;
  }

  item def SecureMediaPacket {
    attribute sessionId : SessionIdentifier;
    attribute encrypted : ScalarValues::Boolean = true;
    attribute authenticated : ScalarValues::Boolean = true;
    attribute payloadBitRate : Bandwidth = 50 [Mbps];
    attribute sequenceNumber : ScalarValues::Integer;
  }

  item def DecodedMedia {
    item video : VideoFrame;
    item audio : AudioFrame;
    item telemetry : PresenceTelemetry;
  }

  item def StartSessionCommand {
    attribute requestedMode : SessionMode = SessionMode::immersive;
    attribute invitedRemoteSite : ScalarValues::String;
    attribute requestedSessionId : SessionIdentifier;
  }

  item def StopSessionCommand {
    attribute sessionId : SessionIdentifier;
    attribute reason : ScalarValues::String;
  }

  item def ControlCommand {
    attribute sessionId : SessionIdentifier;
    attribute commandName : ScalarValues::String;
    attribute commandValue : ScalarValues::String;
  }

  item def SessionEvent {
    attribute sessionId : SessionIdentifier;
    attribute currentState : SessionStateKind;
    attribute networkHealth : NetworkHealthKind;
    attribute message : ScalarValues::String;
  }

  item def AuthenticationResult {
    attribute decision : SecurityDecisionKind;
    attribute userName : PersonName;
    attribute sessionId : SessionIdentifier;
  }

  port def VideoOutPort {
    out item video : VideoFrame;
  }

  port def VideoInPort {
    in item video : VideoFrame;
  }

  port def AudioOutPort {
    out item audio : AudioFrame;
  }

  port def AudioInPort {
    in item audio : AudioFrame;
  }

  port def TelemetryOutPort {
    out item telemetry : PresenceTelemetry;
  }

  port def TelemetryInPort {
    in item telemetry : PresenceTelemetry;
  }

  port def ParticipantPresenceOutPort {
    out item presence : ParticipantPresence;
  }

  port def ParticipantPresenceInPort {
    in item presence : ParticipantPresence;
  }

  port def SecureMediaPort {
    in item inboundPacket : SecureMediaPacket;
    out item outboundPacket : SecureMediaPacket;
  }

  port def DecodedMediaOutPort {
    out item media : DecodedMedia;
  }

  port def DecodedMediaInPort {
    in item media : DecodedMedia;
  }

  port def UserCommandPort {
    in item start : StartSessionCommand;
    in item stop : StopSessionCommand;
    in item command : ControlCommand;
    out item event : SessionEvent;
  }

  port def AuthenticationPort {
    out item startRequest : StartSessionCommand;
    in item authResult : AuthenticationResult;
  }

  port def NetworkStatusPort {
    out item event : SessionEvent;
  }

  action def CaptureLocalPresence {
    out item capturedPresence : ParticipantPresence;
  }

  action def EncodeAndEncryptPresence {
    in item capturedPresence : ParticipantPresence;
    out item secureMedia : SecureMediaPacket;
  }

  action def TransportSecureMedia {
    in item mediaFromLocalSite : SecureMediaPacket;
    out item mediaToRemoteSite : SecureMediaPacket;
  }

  action def DecryptAndDecodeMedia {
    in item secureMedia : SecureMediaPacket;
    out item decodedMedia : DecodedMedia;
  }

  action def RenderRemotePresence {
    in item decodedMedia : DecodedMedia;
  }

  action def MonitorInteractionQuality {
    in item event : SessionEvent;
    out item qualityEvent : SessionEvent;
  }

  action def ConductTelepresenceSession {
    doc /* Primary high-level function: enable geographically separated participants to communicate and collaborate with a realistic sense of shared presence by capturing each participant's audio, video, and presence cues, securely transporting them over a network, and rendering the remote participant at the opposite site with low latency and synchronized audiovisual output. */

    in item localCommand : StartSessionCommand;
    out item localEvent : SessionEvent;

    action captureLocal : CaptureLocalPresence;
    action encodeLocal : EncodeAndEncryptPresence;
    action transport : TransportSecureMedia;
    action decodeRemote : DecryptAndDecodeMedia;
    action renderRemote : RenderRemotePresence;
    action monitorQuality : MonitorInteractionQuality;

    flow captureLocal.capturedPresence to encodeLocal.capturedPresence;
    flow encodeLocal.secureMedia to transport.mediaFromLocalSite;
    flow transport.mediaToRemoteSite to decodeRemote.secureMedia;
    flow decodeRemote.decodedMedia to renderRemote.decodedMedia;
  }

  state def TelepresenceSessionLifecycle {
    doc /* Session behavior for a telepresence endpoint from user request through authenticated connection, media negotiation, active immersive communication, degradation handling, and termination. */

    state poweredOff;
    state idle;
    state authenticating;
    state connecting;
    state negotiatingMedia;
    state active;
    state degraded;
    state reconnecting;
    state terminating;
    state faulted;

    transition initialToPoweredOff first start then poweredOff;
    transition powerOn first poweredOff then idle;
    transition requestSession first idle accept StartSessionCommand then authenticating;
    transition authenticationAccepted first authenticating accept AuthenticationResult then connecting;
    transition networkEstablished first connecting then negotiatingMedia;
    transition codecsNegotiated first negotiatingMedia then active;
    transition networkCongested first active accept SessionEvent then degraded;
    transition qualityRecovered first degraded accept SessionEvent then active;
    transition mediaInterrupted first active accept SessionEvent then reconnecting;
    transition reconnectSucceeded first reconnecting then active;
    transition reconnectFailed first reconnecting then faulted;
    transition userStops first active accept StopSessionCommand then terminating;
    transition degradedUserStops first degraded accept StopSessionCommand then terminating;
    transition terminated first terminating then idle;
    transition resetFault first faulted then idle;
    transition powerOffFromIdle first idle then poweredOff;
  }

  part def CameraArray {
    attribute cameraCount : ScalarValues::Integer = 3;
    attribute horizontalFieldOfView : ViewingAngle = 120 [degree];
    attribute minimumIllumination : Illumination = 250 [lux];

    port videoOut : VideoOutPort;
    port telemetryOut : TelemetryOutPort;
  }

  part def MicrophoneArray {
    attribute microphoneCount : ScalarValues::Integer = 8;
    attribute pickupArc : ViewingAngle = 180 [degree];
    attribute nominalSpeechLevel : AudioLevel = 70 [dB];

    port audioOut : AudioOutPort;
    port telemetryOut : TelemetryOutPort;
  }

  part def DisplayWall {
    attribute displayCount : ScalarValues::Integer = 2;
    attribute width : PixelCount = 7680 [pixel];
    attribute height : PixelCount = 2160 [pixel];
    attribute refreshRate : FrameRate = 60 [fps];

    port videoIn : VideoInPort;
  }

  part def SpeakerArray {
    attribute speakerCount : ScalarValues::Integer = 6;
    attribute nominalOutputLevel : AudioLevel = 72 [dB];

    port audioIn : AudioInPort;
  }

  part def PresenceSensorProcessor {
    attribute faceTrackingMinimumConfidence : Confidence = 0.85;
    attribute gazeTrackingMinimumConfidence : Confidence = 0.80;

    port cameraTelemetryIn : TelemetryInPort;
    port microphoneTelemetryIn : TelemetryInPort;
    port presenceOut : ParticipantPresenceOutPort;
  }

  part def MediaCodec {
    attribute supportedVideoWidth : PixelCount = 3840 [pixel];
    attribute supportedVideoHeight : PixelCount = 2160 [pixel];
    attribute supportedFrameRate : FrameRate = 60 [fps];
    attribute nominalEncodedBitRate : Bandwidth = 50 [Mbps];
    attribute encodeLatency : Latency = 25 [ms];
    attribute decodeLatency : Latency = 25 [ms];

    port rawVideoIn : VideoInPort;
    port rawAudioIn : AudioInPort;
    port presenceIn : ParticipantPresenceInPort;
    port secureMedia : SecureMediaPort;
    port decodedMediaOut : DecodedMediaOutPort;
  }

  part def MediaRenderer {
    attribute audioVideoSynchronizationTolerance : Latency = 20 [ms];
    attribute renderLatency : Latency = 30 [ms];

    port decodedMediaIn : DecodedMediaInPort;
    port videoOut : VideoOutPort;
    port audioOut : AudioOutPort;
  }

  part def NetworkAdapter {
    attribute minimumUplinkBandwidth : Bandwidth = 60 [Mbps];
    attribute minimumDownlinkBandwidth : Bandwidth = 60 [Mbps];
    attribute maximumLocalPacketJitter : Jitter = 10 [ms];

    port media : SecureMediaPort;
    port status : NetworkStatusPort;
  }

  part def AuthenticationService {
    attribute tokenValidityMinutes : ScalarValues::Integer = 60;
    attribute multiFactorRequired : ScalarValues::Boolean = true;

    port authentication : AuthenticationPort;
  }

  part def SessionController {
    attribute currentState : SessionStateKind = SessionStateKind::idle;
    attribute selectedMode : SessionMode = SessionMode::immersive;
    attribute maximumReconnectTime : Latency = 5000 [ms];

    port userCommands : UserCommandPort;
    port authentication : AuthenticationPort;
    port networkStatus : NetworkStatusPort;

    exhibit stateMachine : TelepresenceSessionLifecycle;
    perform action conductSession : ConductTelepresenceSession;
  }

  part def WideAreaNetwork {
    attribute nominalOneWayLatency : Latency = 60 [ms];
    attribute maximumOneWayLatency : Latency = 100 [ms];
    attribute maximumJitter : Jitter = 20 [ms];
    attribute availableBandwidth : Bandwidth = 200 [Mbps];
    attribute availabilityTarget : Availability = 99.9 [percent];

    port siteA : SecureMediaPort;
    port siteB : SecureMediaPort;
  }

  part def TelepresenceSuite {
    doc /* A telepresence endpoint installed at one physical site. It captures local participants, encodes and secures their presence information, exchanges media with a remote suite, and renders the remote participants. */

    attribute siteName : ScalarValues::String;
    attribute supportedMode : SessionMode = SessionMode::immersive;
    attribute maximumEndpointLatency : Latency = 80 [ms];

    part cameras : CameraArray;
    part microphones : MicrophoneArray;
    part displays : DisplayWall;
    part speakers : SpeakerArray;
    part presenceProcessor : PresenceSensorProcessor;
    part codec : MediaCodec;
    part renderer : MediaRenderer;
    part networkAdapter : NetworkAdapter;
    part authenticator : AuthenticationService;
    part controller : SessionController;

    port userInterface : UserCommandPort;
    port networkMedia : SecureMediaPort;

    connection cameraVideoToCodec connect cameras.videoOut to codec.rawVideoIn;
    connection microphoneAudioToCodec connect microphones.audioOut to codec.rawAudioIn;
    connection cameraTelemetryToPresenceProcessor connect cameras.telemetryOut to presenceProcessor.cameraTelemetryIn;
    connection microphoneTelemetryToPresenceProcessor connect microphones.telemetryOut to presenceProcessor.microphoneTelemetryIn;
    connection presenceToCodec connect presenceProcessor.presenceOut to codec.presenceIn;
    connection codecSecureMediaToAdapter connect codec.secureMedia to networkAdapter.media;
    connection adapterToSuiteNetworkPort connect networkAdapter.media to networkMedia;
    connection codecDecodedMediaToRenderer connect codec.decodedMediaOut to renderer.decodedMediaIn;
    connection rendererVideoToDisplay connect renderer.videoOut to displays.videoIn;
    connection rendererAudioToSpeakers connect renderer.audioOut to speakers.audioIn;
    connection uiToController connect userInterface to controller.userCommands;
    connection controllerToAuthenticator connect controller.authentication to authenticator.authentication;
    connection controllerToNetworkStatus connect controller.networkStatus to networkAdapter.status;
  }

  part def TelepresenceSystem {
    doc /* System of two telepresence suites connected through a managed wide-area network to provide an immersive, bidirectional, secure audiovisual meeting capability for geographically separated participants. */

    attribute systemName : ScalarValues::String = "Enterprise Immersive Telepresence System";
    attribute maximumEndToEndMediaLatency : Latency = 150 [ms];
    attribute maximumAudioVideoSkew : Latency = 20 [ms];
    attribute minimumSustainedBandwidthPerDirection : Bandwidth = 50 [Mbps];
    attribute targetAvailability : Availability = 99.9 [percent];

    part localSuite : TelepresenceSuite {
      :>> siteName = "Local Collaboration Room";
    }

    part remoteSuite : TelepresenceSuite {
      :>> siteName = "Remote Collaboration Room";
    }

    part managedNetwork : WideAreaNetwork;

    port localUserInterface : UserCommandPort;
    port remoteUserInterface : UserCommandPort;

    connection localUserToLocalSuite connect localUserInterface to localSuite.userInterface;
    connection remoteUserToRemoteSuite connect remoteUserInterface to remoteSuite.userInterface;
    connection localSuiteToNetwork connect localSuite.networkMedia to managedNetwork.siteA;
    connection remoteSuiteToNetwork connect remoteSuite.networkMedia to managedNetwork.siteB;
  }

  requirement def PrimaryTelepresenceFunctionRequirement {
    doc /* The telepresence system shall enable participants at two geographically separated sites to perceive, hear, and interact with each other in real time as if sharing a common meeting space. */

    subject system : TelepresenceSystem;

    require constraint {
      system.maximumEndToEndMediaLatency <= 150 [ms]
    }

    require constraint {
      system.maximumAudioVideoSkew <= 20 [ms]
    }

    require constraint {
      system.minimumSustainedBandwidthPerDirection >= 50 [Mbps]
    }
  }

  requirement def SecureMediaRequirement {
    doc /* All audiovisual and presence media exchanged between telepresence suites shall be encrypted and authenticated before transmission over the wide-area network. */

    subject packet : SecureMediaPacket;

    require constraint {
      packet.encrypted == true
    }

    require constraint {
      packet.authenticated == true
    }
  }

  requirement def ImmersiveVideoRequirement {
    doc /* Each telepresence suite shall support high-definition immersive video capture and rendering suitable for life-size participant representation. */

    subject suite : TelepresenceSuite;

    require constraint {
      suite.codec.supportedVideoWidth >= 3840 [pixel]
    }

    require constraint {
      suite.codec.supportedVideoHeight >= 2160 [pixel]
    }

    require constraint {
      suite.codec.supportedFrameRate >= 60 [fps]
    }
  }

  requirement def SpatialAudioRequirement {
    doc /* Each telepresence suite shall capture and render spatial speech audio with enough channels to support natural turn taking and remote speaker localization. */

    subject suite : TelepresenceSuite;

    require constraint {
      suite.microphones.microphoneCount >= 6
    }

    require constraint {
      suite.speakers.speakerCount >= 4
    }
  }

  requirement def AvailabilityRequirement {
    doc /* The telepresence system shall provide high service availability for scheduled collaboration sessions. */

    subject system : TelepresenceSystem;

    require constraint {
      system.targetAvailability >= 99.9 [percent]
    }
  }

  requirement def SessionLifecycleRequirement {
    doc /* The telepresence suite shall manage sessions through idle, authentication, connection, negotiation, active communication, degradation handling, termination, and fault recovery states. */

    subject controller : SessionController;

    require constraint {
      controller.maximumReconnectTime <= 5000 [ms]
    }
  }

  part enterpriseTelepresenceSystem : TelepresenceSystem;

  satisfy PrimaryTelepresenceFunctionRequirement by enterpriseTelepresenceSystem;
  satisfy AvailabilityRequirement by enterpriseTelepresenceSystem;
  satisfy ImmersiveVideoRequirement by enterpriseTelepresenceSystem.localSuite;
  satisfy ImmersiveVideoRequirement by enterpriseTelepresenceSystem.remoteSuite;
  satisfy SpatialAudioRequirement by enterpriseTelepresenceSystem.localSuite;
  satisfy SpatialAudioRequirement by enterpriseTelepresenceSystem.remoteSuite;
  satisfy SessionLifecycleRequirement by enterpriseTelepresenceSystem.localSuite.controller;
  satisfy SessionLifecycleRequirement by enterpriseTelepresenceSystem.remoteSuite.controller;

}
