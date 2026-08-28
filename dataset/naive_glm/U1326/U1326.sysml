package VoIP_PBX_System {
    import ScalarValues::*;
    import ISQ::*;
    
    item def SIP_Message;
    item def RTP_Packet;
    item def AudioStream;
    item def CallRecord;
    
    value type ExtensionNumber :> String;
    value type IPAddress :> String;
    value type PortNumber :> Integer;
    value type CallCapacity :> Integer;
    value type CallDuration :> TimeValue;
    
    port def SIP_Port {
        in item sip_msg_in : SIP_Message;
        out item sip_msg_out : SIP_Message;
    }
    
    port def RTP_Port {
        in item rtp_in : RTP_Packet;
        out item rtp_out : RTP_Packet;
    }
    
    port def CDR_Port {
        out item cdr_record : CallRecord;
    }
    
    part def Dial_Plan_Engine {
        port sip_port : SIP_Port;
        
        action def RouteCall {
            in dial_pattern : String;
            out destination : String;
        }
    }
    
    part def Media_Bridge {
        port sip_port : SIP_Port;
        port rtp_port : RTP_Port;
        
        action def BridgeAudio {
            in audio_in : RTP_Packet;
            out audio_out : RTP_Packet;
        }
    }
    
    part def Codec_Translator {
        port rtp_port : RTP_Port;
        
        action def TranslateCodec {
            in audio_in : RTP_Packet;
            out audio_out : RTP_Packet;
        }
    }
    
    part def CDR_Manager {
        port cdr_port : CDR_Port;
        
        action def LogCall {
            in record : CallRecord;
        }
    }
    
    part def Registrar {
        port sip_port : SIP_Port;
        
        action def RegisterEndpoint {
            in ext : ExtensionNumber;
            in ip : IPAddress;
        }
    }
    
    part def SIP_Endpoint {
        attribute extension : ExtensionNumber;
        attribute ip_address : IPAddress;
        port sip_port : SIP_Port;
        port rtp_port : RTP_Port;
    }
    
    part def SIP_Trunk {
        attribute provider_ip : IPAddress;
        port sip_port : SIP_Port;
        port rtp_port : RTP_Port;
    }
    
    part def PBX_Core {
        attribute max_calls : CallCapacity = 100;
        attribute call_requested : Boolean = false;
        attribute call_answered : Boolean = false;
        attribute call_ended : Boolean = false;
        
        port sip_port : SIP_Port;
        port cdr_port : CDR_Port;
        
        part dial_plan : Dial_Plan_Engine;
        part registrar : Registrar;
        part media_bridge : Media_Bridge;
        part codec_translator : Codec_Translator;
        part cdr_manager : CDR_Manager;
        
        connect sip_port to dial_plan.sip_port;
        connect dial_plan.sip_port to registrar.sip_port;
        connect dial_plan.sip_port to media_bridge.sip_port;
        connect media_bridge.rtp_port to codec_translator.rtp_port;
        connect cdr_manager.cdr_port to cdr_port;
        
        state def CallLifecycle {
            entry; then Idle;
            state Idle;
            state Ringing;
            state Answered;
            state Disconnected;
            
            transition idle_to_ringing
                first Idle
                if call_requested
                then Ringing;
                
            transition ringing_to_answered
                first Ringing
                if call_answered
                then Answered;
                
            transition answered_to_disconnected
                first Answered
                if call_ended
                then Disconnected;
                
            transition disconnected_to_idle
                first Disconnected
                then Idle;
        }
    }
    
    part def VoIP_PBX {
        part core : PBX_Core;
        part endpoints : SIP_Endpoint[*];
        part trunk : SIP_Trunk;
        
        connect endpoints.sip_port to core.sip_port;
        connect endpoints.rtp_port to core.media_bridge.rtp_port;
        connect trunk.sip_port to core.sip_port;
        connect trunk.rtp_port to core.media_bridge.rtp_port;
    }
    
    requirement def PBX_Requirements {
        requirement RouteCalls {
            doc /* The system shall route internal and external calls based on dial plan rules. */
        }
        requirement BridgeMedia {
            doc /* The system shall bridge RTP media streams between connected parties. */
        }
        requirement TranslateCodecs {
            doc /* The system shall translate between incompatible audio codecs. */
        }
        requirement LogCDR {
            doc /* The system shall log call details for every call. */
        }
        requirement RegisterEndpoints {
            doc /* The system shall maintain a registry of connected SIP endpoints. */
        }
    }
}
