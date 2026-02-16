package TrachealIntubationSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    
    package ValueTypes {
        attribute def TubeSize :> ISQ::LengthValue;
        attribute def CuffPressure :> ISQ::PressureValue;
        attribute def OxygenSaturation :> Real;
        attribute def EndTidalCO2 :> ISQ::PressureValue;
        attribute def TidalVolume :> ISQ::VolumeValue;
        attribute def RespiratoryRate :> Real;
        attribute def AirwayPressure :> ISQ::PressureValue;
        attribute def InsertionDepth :> ISQ::LengthValue;
        
        item def GasMixture {
            attribute oxygenConcentration : Real;
            attribute flowRate : ISQ::VolumeFlowRateValue;
            attribute pressure : ISQ::PressureValue;
        }
        
        item def VitalSigns {
            attribute heartRate : Real;
            attribute bloodPressure : ISQ::PressureValue;
            attribute spO2 : OxygenSaturation;
            attribute etCO2 : EndTidalCO2;
        }
    }
    
    package PortDefinitions {
        private import ValueTypes::*;
        
        port def AirwayPort {
            in gasMixIn : GasMixture;
            out gasMixOut : GasMixture;
            out airwayPressure : AirwayPressure;
        }
        
        port def MonitoringPort {
            out vitals : VitalSigns;
        }
        
        port def VentilatorPort {
            out deliveredGas : GasMixture;
            in returnedGas : GasMixture;
            out peakPressure : AirwayPressure;
        }
        
        port def CuffPort {
            in inflationPressure : CuffPressure;
        }
    }
    
    package ComponentDefinitions {
        private import ValueTypes::*;
        private import PortDefinitions::*;
        
        part def Laryngoscope {
            attribute bladeType : String;
            attribute lightIntensity : ISQ::LuminousIntensityValue;
            attribute isActivated : Boolean;
            
            action activateLight {
                in command : Boolean;
                out lightOn : Boolean;
            }
        }
        
        part def EndotrachealTube {
            attribute tubeSize : TubeSize;
            attribute cuffPressure : CuffPressure;
            attribute insertionDepth : InsertionDepth;
            attribute hasCuff : Boolean;
            
            port proximalEnd : AirwayPort;
            port distalEnd : AirwayPort;
            port cuffInflation : CuffPort;
        }
        
        part def MechanicalVentilator {
            attribute tidalVolume : TidalVolume;
            attribute respiratoryRate : RespiratoryRate;
            attribute peakPressure : AirwayPressure;
            attribute oxygenFraction : Real;
            attribute isActive : Boolean;
            
            port ventOutput : VentilatorPort;
            
            state ventilatorStates {
                entry; then idle;
                
                state idle;
                state ventilating {
                    entry assign isActive := true;
                    do action deliverBreath {
                        out breath : GasMixture;
                    }
                }
                state alarm;
                
                accept startVentilation
                    then transition idle to ventilating;
                    
                accept stopVentilation
                    then transition ventilating to idle;
                    
                transition ventilating to alarm
                    if peakPressure.num > 40.0;
                    
                accept resetAlarm
                    then transition alarm to ventilating;
            }
        }
        
        part def PatientMonitor {
            attribute currentSpO2 : OxygenSaturation;
            attribute currentEtCO2 : EndTidalCO2;
            attribute currentHeartRate : Real;
            
            port monitoring : MonitoringPort;
            
            action continuousMonitoring {
                loop {
                    action measureVitals {
                        out vitals : VitalSigns;
                    }
                    then assign currentSpO2 := measureVitals.vitals.spO2;
                    then assign currentEtCO2 := measureVitals.vitals.etCO2;
                    then assign currentHeartRate := measureVitals.vitals.heartRate;
                }
            }
        }
        
        part def SuctionDevice {
            attribute suctionPressure : ISQ::PressureValue;
            attribute isActive : Boolean;
            
            action clearAirway {
                in duration : ISQ::DurationValue;
                out airwayClear : Boolean;
            }
        }
        
        part def Patient {
            attribute airwayPatency : Boolean;
            attribute consciousnessLevel : Real;
            attribute oxygenSaturation : OxygenSaturation;
            
            port airway : AirwayPort;
            port vitalsOutput : MonitoringPort;
        }
    }
    
    package ActionDefinitions {
        private import ValueTypes::*;
        
        action def PreOxygenate {
            in currentSpO2 : OxygenSaturation;
            in targetSpO2 : OxygenSaturation;
            out oxygenationComplete : Boolean;
        }
        
        action def PositionPatient {
            in patientCondition : String;
            out headPosition : String;
            out neckAlignment : Boolean;
        }
        
        action def VisualizeLarynx {
            in laryngoscopeActive : Boolean;
            out vocalCordsVisible : Boolean;
            out glotticOpening : Boolean;
        }
        
        action def InsertTube {
            in tubeSize : TubeSize;
            in vocalCordsVisible : Boolean;
            out tubeInserted : Boolean;
            out insertionDepth : InsertionDepth;
        }
        
        action def InflateCuff {
            in targetPressure : CuffPressure;
            out cuffInflated : Boolean;
            out finalPressure : CuffPressure;
        }
        
        action def ConfirmPlacement {
            in etCO2Value : EndTidalCO2;
            in chestRise : Boolean;
            in bilateralBreathSounds : Boolean;
            out placementConfirmed : Boolean;
        }
        
        action def SecureTube {
            in tubeDepth : InsertionDepth;
            out tubeSecured : Boolean;
        }
        
        action def InitiateVentilation {
            in tubeSecured : Boolean;
            in targetTidalVolume : TidalVolume;
            in targetRate : RespiratoryRate;
            out ventilationStarted : Boolean;
        }
    }
    
    package RequirementDefinitions {
        requirement def AirwaySecurityRequirement {
            doc /* The endotracheal tube shall be positioned in the trachea 
                    at a depth of 21-23 cm from the incisors for adult patients 
                    and secured to prevent displacement. */
        }
        
        requirement def OxygenationRequirement {
            doc /* The system shall maintain patient oxygen saturation 
                    at or above 92% during and after intubation. */
        }
        
        requirement def VentilationConfirmationRequirement {
            doc /* Proper tube placement shall be confirmed by end-tidal CO2 
                    detection with values between 35-45 mmHg and bilateral 
                    chest rise. */
        }
        
        requirement def CuffPressureRequirement {
            doc /* The endotracheal tube cuff pressure shall be maintained 
                    between 20-30 cmH2O to prevent aspiration while avoiding 
                    tracheal mucosal injury. */
        }
        
        requirement def TimingRequirement {
            doc /* The intubation procedure from laryngoscopy to confirmation 
                    shall be completed within 30 seconds to minimize hypoxia risk. */
        }
        
        requirement def PrimaryFunctionRequirement {
            doc /* The tracheal intubation system shall establish and maintain 
                    a secure artificial airway to enable mechanical ventilation 
                    and protect the airway from aspiration. */
        }
    }
    
    package SystemUsage {
        private import ComponentDefinitions::*;
        private import ActionDefinitions::*;
        private import RequirementDefinitions::*;
        private import ValueTypes::*;
        private import PortDefinitions::*;
        
        part trachealIntubationSystem {
            doc /* The tracheal intubation system provides emergency and elective 
                    airway management by establishing a secure endotracheal airway, 
                    enabling controlled mechanical ventilation, airway protection, 
                    and delivery of supplemental oxygen to patients requiring 
                    respiratory support. */
            
            part patient : Patient;
            part laryngoscope : Laryngoscope;
            part endotrachealTube : EndotrachealTube {
                attribute :>> tubeSize = 7.5;
                attribute :>> hasCuff = true;
            }
            part ventilator : MechanicalVentilator {
                attribute :>> tidalVolume = 500.0;
                attribute :>> respiratoryRate = 12.0;
                attribute :>> oxygenFraction = 1.0;
            }
            part monitor : PatientMonitor {
                perform intubationProcedure.monitorContinuously;
            }
            part suction : SuctionDevice;
            
            connection tubeToPatient connect endotrachealTube.distalEnd to patient.airway;
            connection ventilatorToTube connect ventilator.ventOutput to endotrachealTube.proximalEnd;
            connection patientToMonitor connect patient.vitalsOutput to monitor.monitoring;
            
            action intubationProcedure {
                doc /* Complete tracheal intubation procedure from preparation 
                        through confirmation and initiation of mechanical ventilation. */
                
                first start;
                
                then action preoxygenate : PreOxygenate {
                    in currentSpO2 : OxygenSaturation;
                    in targetSpO2 = 100.0;
                    out oxygenationComplete;
                }
                
                then action positionPatient : PositionPatient {
                    in patientCondition = "supine";
                    out headPosition;
                    out neckAlignment;
                }
                
                then action activateLaryngoscope {
                    out scopeReady : Boolean;
                }
                
                then action visualizeLarynx : VisualizeLarynx {
                    in laryngoscopeActive = activateLaryngoscope.scopeReady;
                    out vocalCordsVisible;
                    out glotticOpening;
                }
                
                then decide;
                    if visualizeLarynx.vocalCordsVisible and visualizeLarynx.glotticOpening 
                        then insertTube;
                    else repositionAndRetry;
                
                action repositionAndRetry {
                    then merge retryVisualization;
                }
                
                merge retryVisualization;
                then visualizeLarynx;
                
                action insertTube : InsertTube {
                    in tubeSize = endotrachealTube.tubeSize;
                    in vocalCordsVisible = visualizeLarynx.vocalCordsVisible;
                    out tubeInserted;
                    out insertionDepth;
                }
                
                then action removeLaryngoscope;
                
                then action inflateCuff : InflateCuff {
                    in targetPressure = 25.0;
                    out cuffInflated;
                    out finalPressure;
                }
                
                then assign endotrachealTube.cuffPressure := inflateCuff.finalPressure;
                then assign endotrachealTube.insertionDepth := insertTube.insertionDepth;
                
                then action confirmPlacement : ConfirmPlacement {
                    in etCO2Value : EndTidalCO2;
                    in chestRise = true;
                    in bilateralBreathSounds = true;
                    out placementConfirmed;
                }
                
                then decide;
                    if confirmPlacement.placementConfirmed then secureTube;
                    else removeAndRetry;
                
                action removeAndRetry {
                    action deflateCuff;
                    then action removeTube;
                    then merge retryVisualization;
                }
                
                action secureTube : SecureTube {
                    in tubeDepth = endotrachealTube.insertionDepth;
                    out tubeSecured;
                }
                
                then action initiateVentilation : InitiateVentilation {
                    in tubeSecured = secureTube.tubeSecured;
                    in targetTidalVolume = ventilator.tidalVolume;
                    in targetRate = ventilator.respiratoryRate;
                    out ventilationStarted;
                }
                
                then assign ventilator.isActive := initiateVentilation.ventilationStarted;
                
                then action monitorContinuously {
                    loop {
                        action checkVitals {
                            out spO2 : OxygenSaturation;
                            out etCO2 : EndTidalCO2;
                            out cuffPressure : CuffPressure;
                        }
                        
                        then decide;
                            if checkVitals.spO2 >= 92.0 and 
                               checkVitals.etCO2.num >= 35.0 and 
                               checkVitals.etCO2.num <= 45.0 and
                               checkVitals.cuffPressure.num >= 20.0 and
                               checkVitals.cuffPressure.num <= 30.0
                                then maintainVentilation;
                            else adjustParameters;
                        
                        action maintainVentilation;
                        
                        action adjustParameters {
                            action adjustVentilatorSettings;
                            then action adjustCuffPressure;
                        }
                    }
                }
                
                then done;
            }
            
            satisfy airwaySecurity : AirwaySecurityRequirement by endotrachealTube;
            satisfy oxygenation : OxygenationRequirement by ventilator;
            satisfy ventilationConfirmation : VentilationConfirmationRequirement by monitor;
            satisfy cuffPressure : CuffPressureRequirement by endotrachealTube.cuffPressure;
            satisfy timing : TimingRequirement by intubationProcedure;
            satisfy primaryFunction : PrimaryFunctionRequirement by this;
        }
    }
}
