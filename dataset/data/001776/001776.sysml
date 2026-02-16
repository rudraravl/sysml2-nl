package 'Federal Signal Emergency Warning System' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package Definitions {
        
        enum def AlertPriorityLevel {
            enum routine;
            enum urgent;
            enum critical;
            enum emergency;
        }
        
        enum def SirenTonePattern {
            enum wail;
            enum yelp;
            enum piercer;
            enum hyperYelp;
            enum manual;
        }
        
        enum def LightFlashPattern {
            enum steady;
            enum singleFlash;
            enum doubleFlash;
            enum tripleFlash;
            enum rotating;
        }
        
        attribute def EmergencyCommand {
            attribute priority : AlertPriorityLevel;
            attribute sirenTone : SirenTonePattern;
            attribute lightPattern : LightFlashPattern;
            attribute activationTimestamp : TimeValue;
        }
        
        item def ElectricalPower {
            attribute voltage : ElectricPotentialValue;
            attribute current : ElectricCurrentValue;
            attribute power : PowerValue;
        }
        
        item def AcousticOutput {
            attribute frequency : FrequencyValue;
            attribute soundPressureLevel : PressureValue;
            attribute decibels : Real;
        }
        
        item def OpticalOutput {
            attribute luminousIntensity : LuminousIntensityValue;
            attribute wavelength : LengthValue;
            attribute flashRate : Real;
        }
        
        port def PowerInputPort {
            in item powerSupply : ElectricalPower;
        }
        
        port def CommandInputPort {
            in item command : EmergencyCommand;
        }
        
        port def AcousticOutputPort {
            out item acousticSignal : AcousticOutput;
        }
        
        port def OpticalOutputPort {
            out item opticalSignal : OpticalOutput;
        }
        
        part def ControlProcessor {
            port cmdIn : CommandInputPort;
            port pwrIn : PowerInputPort;
            port sirenCtrl : CommandInputPort;
            port lightCtrl : CommandInputPort;
            
            attribute activeCommand : EmergencyCommand;
            attribute systemStatus : Boolean;
            attribute diagnosticCode : Integer;
        }
        
        part def SirenDriver {
            port controlInput : CommandInputPort;
            port powerInput : PowerInputPort;
            port acousticOut : AcousticOutputPort;
            
            attribute amplifierGain : Real;
            attribute outputFrequency : FrequencyValue;
            attribute maxOutputPower : PowerValue;
        }
        
        part def LightController {
            port controlInput : CommandInputPort;
            port powerInput : PowerInputPort;
            port opticalOut : OpticalOutputPort;
            
            attribute ledDriveLevel : Real;
            attribute currentPattern : LightFlashPattern;
            attribute dutyCycle : Real;
        }
        
        part def SpeakerArray {
            port audioIn : AcousticOutputPort;
            
            attribute speakerCount : Integer;
            attribute impedance : Real;
            attribute maxSPL : PressureValue;
            attribute coverageAngle : PlaneAngleValue;
        }
        
        part def LEDLightHead {
            port lightIn : OpticalOutputPort;
            
            attribute ledCount : Integer;
            attribute beamAngle : PlaneAngleValue;
            attribute colorTemperature : ThermodynamicTemperatureValue;
            attribute effectiveRange : LengthValue;
        }
        
        part def PowerSupplyUnit {
            port vehiclePowerIn : PowerInputPort;
            port regulatedPowerOut : PowerInputPort;
            port batteryBackup : PowerInputPort;
            
            attribute inputVoltageMin : ElectricPotentialValue;
            attribute inputVoltageMax : ElectricPotentialValue;
            attribute outputVoltage : ElectricPotentialValue;
            attribute backupCapacity : EnergyValue;
        }
        
        action def ProcessEmergencyCommand {
            in emergencyCmd : EmergencyCommand;
            out sirenControl : SirenTonePattern;
            out lightControl : LightFlashPattern;
            out priorityLevel : AlertPriorityLevel;
        }
        
        action def GenerateSirenOutput {
            in tonePattern : SirenTonePattern;
            in powerLevel : PowerValue;
            out acousticSignal : AcousticOutput;
        }
        
        action def GenerateLightOutput {
            in flashPattern : LightFlashPattern;
            in powerLevel : PowerValue;
            out opticalSignal : OpticalOutput;
        }
        
        action def MonitorSystemHealth {
            in powerStatus : ElectricalPower;
            in commandStatus : EmergencyCommand;
            out healthStatus : Boolean;
            out diagnostics : Integer;
        }
        
        action def ProvideEmergencyWarning {
            in emergencyActivation : EmergencyCommand;
            in vehiclePower : ElectricalPower;
            out acousticWarning : AcousticOutput;
            out visualWarning : OpticalOutput;
            
            first start;
            then merge monitoringLoop;
            
            then action healthCheck : MonitorSystemHealth {
                in powerStatus = vehiclePower;
                in commandStatus = emergencyActivation;
                out healthStatus : Boolean;
                out diagnostics : Integer;
            }
            
            then decide;
                if healthCheck.healthStatus and emergencyActivation.priority != AlertPriorityLevel::routine
                    then activateWarning;
                if not healthCheck.healthStatus or emergencyActivation.priority == AlertPriorityLevel::routine
                    then monitoringLoop;
            
            action activateWarning {
                first action processCmd : ProcessEmergencyCommand {
                    in emergencyCmd = emergencyActivation;
                    out sirenControl : SirenTonePattern;
                    out lightControl : LightFlashPattern;
                    out priorityLevel : AlertPriorityLevel;
                }
                
                then action emitAcoustic : GenerateSirenOutput {
                    in tonePattern = processCmd.sirenControl;
                    in powerLevel = vehiclePower.power;
                    out acousticSignal = acousticWarning;
                }
                
                then action emitOptical : GenerateLightOutput {
                    in flashPattern = processCmd.lightControl;
                    in powerLevel = vehiclePower.power;
                    out opticalSignal = visualWarning;
                }
            }
            
            then monitoringLoop;
        }
        
        part def EmergencyWarningSystem {
            attribute systemIdentifier : String;
            attribute installationDate : TimeValue;
            attribute operatingMode : String;
            
            part processor : ControlProcessor;
            part sirenAmp : SirenDriver;
            part lightCtrl : LightController;
            part speakers : SpeakerArray[4];
            part lightHeads : LEDLightHead[6];
            part powerUnit : PowerSupplyUnit;
            
            connection powerToProcessor : PowerConnection
                connect powerUnit.regulatedPowerOut to processor.pwrIn;
            
            connection powerToSiren : PowerConnection
                connect powerUnit.regulatedPowerOut to sirenAmp.powerInput;
            
            connection powerToLights : PowerConnection
                connect powerUnit.regulatedPowerOut to lightCtrl.powerInput;
            
            connection sirenCommandLink : ControlConnection
                connect processor.sirenCtrl to sirenAmp.controlInput;
            
            connection lightCommandLink : ControlConnection
                connect processor.lightCtrl to lightCtrl.controlInput;
            
            connection acousticToSpeakers : AcousticConnection
                connect sirenAmp.acousticOut to speakers[1].audioIn;
            
            connection opticalToLightHeads : OpticalConnection
                connect lightCtrl.opticalOut to lightHeads[1].lightIn;
        }
        
        connection def PowerConnection {
            end supplier : PowerInputPort;
            end consumer : PowerInputPort;
        }
        
        connection def ControlConnection {
            end controller : CommandInputPort;
            end controlled : CommandInputPort;
        }
        
        connection def AcousticConnection {
            end source : AcousticOutputPort;
            end destination : AcousticOutputPort;
        }
        
        connection def OpticalConnection {
            end source : OpticalOutputPort;
            end destination : OpticalOutputPort;
        }
    }
    
    package Usages {
        import Definitions::*;
        
        part federalSignalWarningSystem : EmergencyWarningSystem {
            :>> systemIdentifier = "FS-EWS-2024-001";
            :>> operatingMode = "Emergency Response";
            
            perform action warningOperation[*] ordered references provideWarning;
            
            part :>> processor {
                perform warningOperation.healthCheck;
                perform warningOperation.activateWarning.processCmd;
            }
            
            part :>> sirenAmp {
                perform warningOperation.activateWarning.emitAcoustic;
                :>> maxOutputPower = 200[W];
            }
            
            part :>> lightCtrl {
                perform warningOperation.activateWarning.emitOptical;
                :>> dutyCycle = 0.5;
            }
            
            part :>> speakers {
                :>> speakerCount = 2;
                :>> impedance = 8.0;
                :>> maxSPL = 125[Pa];
                :>> coverageAngle = 120[°];
            }
            
            part :>> lightHeads {
                :>> ledCount = 12;
                :>> beamAngle = 45[°];
                :>> effectiveRange = 500[m];
            }
            
            part :>> powerUnit {
                :>> inputVoltageMin = 10[V];
                :>> inputVoltageMax = 16[V];
                :>> outputVoltage = 12[V];
                :>> backupCapacity = 500[W*h];
            }
        }
        
        action provideWarning : ProvideEmergencyWarning {
            in emergencyActivation : EmergencyCommand {
                :>> priority = AlertPriorityLevel::emergency;
                :>> sirenTone = SirenTonePattern::wail;
                :>> lightPattern = LightFlashPattern::tripleFlash;
                :>> activationTimestamp = 0[s];
            }
            
            in vehiclePower : ElectricalPower {
                :>> voltage = 12[V];
                :>> current = 40[A];
                :>> power = 480[W];
            }
            
            out acousticWarning : AcousticOutput {
                :>> frequency = 800[Hz];
                :>> soundPressureLevel = 125[Pa];
                :>> decibels = 120.0;
            }
            
            out visualWarning : OpticalOutput {
                :>> luminousIntensity = 2000[cd];
                :>> wavelength = 625[nm];
                :>> flashRate = 3.0;
            }
        }
    }
    
    package Requirements {
        import Definitions::*;
        import Usages::*;
        
        requirement <'FS-REQ-001'> emergencyResponseRequirement {
            doc /* The Federal Signal emergency warning system shall provide 
                 simultaneous audible and visual alerts to warn and notify 
                 personnel and the public of emergency situations within 
                 300 milliseconds of receiving an activation command. */
            
            subject federalSignalWarningSystem;
            
            require constraint activationLatency {
                provideWarning.emergencyActivation.activationTimestamp <= 0.3[s]
            }
            
            require constraint acousticPerformance {
                provideWarning.acousticWarning.decibels >= 110.0
            }
            
            require constraint visualPerformance {
                provideWarning.visualWarning.luminousIntensity >= 1000[cd]
            }
        }
        
        requirement <'FS-REQ-002'> powerReliabilityRequirement {
            doc /* The system shall operate continuously from vehicle electrical 
                 power and automatically switch to battery backup within 50 
                 milliseconds of primary power loss, maintaining full warning 
                 capability for minimum 30 minutes. */
            
            subject federalSignalWarningSystem;
            
            require constraint primaryPowerRange {
                provideWarning.vehiclePower.voltage >= 10[V] and 
                provideWarning.vehiclePower.voltage <= 16[V]
            }
            
            require constraint backupDuration {
                federalSignalWarningSystem.powerUnit.backupCapacity >= 240[W*h]
            }
        }
        
        requirement <'FS-REQ-003'> acousticCoverageRequirement {
            doc /* The siren system shall produce omnidirectional sound output 
                 with minimum 120 dB SPL at 1 meter distance and maintain 
                 audibility at 500 meters in ambient noise conditions. */
            
            subject federalSignalWarningSystem;
            
            require constraint soundPressureLevel {
                provideWarning.acousticWarning.soundPressureLevel >= 120[Pa]
            }
            
            require constraint speakerCoverage {
                federalSignalWarningSystem.speakers[1].coverageAngle >= 90[°]
            }
        }
        
        requirement <'FS-REQ-004'> opticalVisibilityRequirement {
            doc /* The light system shall provide 360-degree horizontal visibility 
                 with minimum 2000 candela effective intensity and be visible 
                 from 500 meters in daylight conditions. */
            
            subject federalSignalWarningSystem;
            
            require constraint lightIntensity {
                provideWarning.visualWarning.luminousIntensity >= 2000[cd]
            }
            
            require constraint visibilityRange {
                federalSignalWarningSystem.lightHeads[1].effectiveRange >= 500[m]
            }
        }
        
        requirement <'FS-REQ-005'> systemReliabilityRequirement {
            doc /* The emergency warning system shall continuously monitor 
                 operational health and provide diagnostic feedback with 
                 99.9% uptime reliability over 5-year service life. */
            
            subject federalSignalWarningSystem;
            
            require constraint healthMonitoring {
                provideWarning.healthCheck.healthStatus == true
            }
            
            require constraint diagnosticCapability {
                provideWarning.healthCheck.diagnostics >= 0
            }
        }
        
        requirement <'FS-MISSION'> federalSignalMission {
            doc /* Provide reliable, high-intensity emergency warning through 
                 integrated audible and visual signaling to protect first 
                 responders and the public during emergency operations. */
            
            require emergencyResponseRequirement;
            require powerReliabilityRequirement;
            require acousticCoverageRequirement;
            require opticalVisibilityRequirement;
            require systemReliabilityRequirement;
        }
    }
}
