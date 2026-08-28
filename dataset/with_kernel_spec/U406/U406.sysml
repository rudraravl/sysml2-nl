package 'Surgical Lighting System' {
    private import ISQ::*;
    private import ScalarValues::*;
    public import Definitions::*;
    
    package Definitions {
        item def ElectricalPower;
        item def LightBeam;
        item def Airflow;
        
        attribute def OnCmd;
        attribute def OffCmd;
        attribute def SetBrightnessCmd { attribute brightness : Real; }
        attribute def SetModeCmd { attribute mode : String; }
        attribute def SetPositionCmd { attribute position : Real; }
        
        port def CommandPort {
            attribute onCmd : OnCmd;
            attribute offCmd : OffCmd;
            attribute setBrightness : SetBrightnessCmd;
            attribute setMode : SetModeCmd;
            attribute setPosition : SetPositionCmd;
        }
        port def LEDControlPort {
            attribute brightness : Real;
            attribute colorTemp : TemperatureValue;
        }
        port def FanControlPort {
            attribute fanSpeed : Real;
        }
        port def ArmControlPort {
            attribute lock : Boolean;
            attribute position : Real;
        }
        port def TempPort {
            attribute temp : TemperatureValue;
        }
        port def PowerPort {
            item power : ElectricalPower;
        }
        port def LightPort {
            item light : LightBeam;
        }
        
        part def SurgicalLightingSystem {
            part controlUnit : ControlUnit;
            part lightHead : LightHead;
            part arm : ArticulatingArm;
            part handle : SterileHandle;
            part powerSupply : PowerSupply;
            
            connect powerSupply.dcOut to lightHead.powerIn;
            connect controlUnit.ledCtrlPort to lightHead.ledCtrl;
            connect controlUnit.fanCtrlPort to lightHead.fanCtrl;
            connect lightHead.tempFeedback to controlUnit.tempFeedbackPort;
            connect controlUnit.armCtrlPort to arm.ctrlPort;
        }
        
        part def ControlUnit {
            in port cmdPort : CommandPort;
            out port ledCtrlPort : LEDControlPort;
            out port fanCtrlPort : FanControlPort;
            out port armCtrlPort : ArmControlPort;
            in port tempFeedbackPort : TempPort;
            
            exhibit state controlStates {
                entry; then off;
                state off;
                accept OnCmd then on;
                state on {
                    entry; then surgicalMode;
                    state surgicalMode;
                    accept s : SetModeCmd if s.mode == "Examination" then examinationMode;
                    accept s : SetModeCmd if s.mode == "Endoscopy" then endoscopyMode;
                    
                    state examinationMode;
                    accept s : SetModeCmd if s.mode == "Surgical" then surgicalMode;
                    accept s : SetModeCmd if s.mode == "Endoscopy" then endoscopyMode;
                    
                    state endoscopyMode;
                    accept s : SetModeCmd if s.mode == "Surgical" then surgicalMode;
                    accept s : SetModeCmd if s.mode == "Examination" then examinationMode;
                }
                accept OffCmd then off;
            }
        }
        
        part def LightHead {
            in port powerIn : PowerPort;
            in port ledCtrl : LEDControlPort;
            in port fanCtrl : FanControlPort;
            out port tempFeedback : TempPort;
            
            part ledModule : LEDModule;
            part opticalAssembly : OpticalAssembly;
            part coolingFan : CoolingFan;
            part tempSensor : TemperatureSensor;
            
            connect powerIn to ledModule.powerIn;
            connect ledCtrl to ledModule.controlIn;
            connect fanCtrl to coolingFan.controlIn;
            connect tempSensor.tempOut to tempFeedback;
            connect ledModule.lightOut to opticalAssembly.lightIn;
        }
        
        part def LEDModule {
            attribute ledCount : Integer = 60;
            in port powerIn : PowerPort;
            in port controlIn : LEDControlPort;
            out port lightOut : LightPort;
        }
        
        part def OpticalAssembly {
            in port lightIn : LightPort;
            out port focusedLightOut : LightPort;
            attribute beamDiameter : LengthValue;
        }
        
        part def CoolingFan {
            in port controlIn : FanControlPort;
            out item airflowOut : Airflow;
        }
        
        part def TemperatureSensor {
            out port tempOut : TempPort;
        }
        
        part def ArticulatingArm {
            attribute maxReach : LengthValue = 2.0 [m];
            attribute isLocked : Boolean = false;
            in port ctrlPort : ArmControlPort;
        }
        
        part def SterileHandle {
            attribute isAutoclavable : Boolean = true;
        }
        
        part def PowerSupply {
            in port acIn : PowerPort;
            out port dcOut : PowerPort;
        }
        
        requirement def 'Provide Surgical Illumination' {
            subject system : SurgicalLightingSystem;
            requirement 'Reach' {
                subject arm : ArticulatingArm;
                constraint { arm.maxReach >= 2.0 [m] }
            }
            requirement 'Sterile Handling' {
                subject handle : SterileHandle;
                constraint { handle.isAutoclavable == true }
            }
            requirement 'LED Count' {
                subject ledModule : LEDModule;
                constraint { ledModule.ledCount == 60 }
            }
        }
    }
    
    package Usages {
        private import Definitions::*;
        
        part system : SurgicalLightingSystem;
        
        requirement 'System Requirements' : 'Provide Surgical Illumination' {
            subject system : SurgicalLightingSystem;
        }
    }
}
