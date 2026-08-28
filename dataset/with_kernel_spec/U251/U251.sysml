package HybridOperatingRoomSystem {
    attribute def Length :> Real;
    attribute def Angle :> Real;
    attribute def Temperature :> Real;
    attribute def Humidity :> Real;
    attribute def Pressure :> Real;
    attribute def FlowRate :> Real;
    attribute def Volume :> Real;
    attribute def LightIntensity :> Real;
    attribute def ColorTemperature :> Real;
    attribute def HeartRate :> Real;
    attribute def OxygenSaturation :> Real;
    attribute def BloodPressure :> Real;
    attribute def RadiationDose :> Real;
    attribute def RespiratoryRate :> Real;
    
    item def ImageData;
    item def InstrumentPosition {
        attribute x : Length;
        attribute y : Length;
        attribute z : Length;
    }
    item def VitalsData {
        attribute heartRate : HeartRate;
        attribute oxygenSaturation : OxygenSaturation;
        attribute bloodPressure : BloodPressure;
        attribute temperature : Temperature;
    }
    item def TablePosition {
        attribute height : Length;
        attribute tilt : Angle;
        attribute lateral : Length;
        attribute longitudinal : Length;
    }
    
    port def ImagePort {
        out image : ImageData;
        out dose : RadiationDose;
    }
    port def TableControlPort {
        in targetPosition : TablePosition;
        out currentPosition : TablePosition;
    }
    port def VitalsPort {
        out vitals : VitalsData;
        out alarm : Boolean;
    }
    port def AnesthesiaPort {
        in flowRateCmd : FlowRate;
        in respRateCmd : RespiratoryRate;
        in tidalVolumeCmd : Volume;
    }
    port def LightingPort {
        in intensityCmd : LightIntensity;
        in colorTempCmd : ColorTemperature;
        in focusCmd : Angle;
    }
    port def EnvironmentalPort {
        in tempCmd : Temperature;
        in humidityCmd : Humidity;
        out currentTemp : Temperature;
        out currentPressure : Pressure;
    }
    port def DisplayPort {
        in image : ImageData;
        in vitals : VitalsData;
        in overlay : InstrumentPosition;
    }
    port def NavigationPort {
        out position : InstrumentPosition;
        in referenceImage : ImageData;
    }
    
    part def ImagingSystem {
        port imgOut : ImagePort;
        attribute cumulativeDose : RadiationDose;
        part xRaySource;
        part detector;
        
        state machine imagingStates {
            state Idle {
                transition to Positioning on startImaging;
            }
            state Positioning {
                transition to Acquiring on positionComplete;
            }
            state Acquiring {
                transition to Processing on captureComplete;
            }
            state Processing {
                transition to Transmitting on processComplete;
            }
            state Transmitting {
                transition to Idle on transmitComplete;
            }
            initial state Idle;
        }
        
        perform action acquireImages {
            out image : ImageData;
            out dose : RadiationDose;
            first start;
            then action positionCarm;
            then action acquireXRay;
            then action processImage;
            then action transmitImage;
            then done;
        }
    }
    
    part def SurgicalTable {
        port tableCtrl : TableControlPort;
        attribute currentHeight : Length;
        attribute currentTilt : Angle;
        attribute currentLateral : Length;
        attribute currentLongitudinal : Length;
        
        perform action adjustPosition {
            in target : TablePosition;
            first start;
            then action setHeight;
            then action setTilt;
            then action setLateral;
            then action setLongitudinal;
            then done;
        }
    }
    
    part def PatientMonitoringSystem {
        port vitalsOut : VitalsPort;
        part ecgMonitor;
        part pulseOximeter;
        part bloodPressureMonitor;
        part temperatureSensor;
        
        state machine monitoringStates {
            state Normal {
                transition to Alarm on vitalOutOfRange;
            }
            state Alarm {
                transition to Normal on vitalNormalized;
            }
            initial state Normal;
        }
        
        perform action monitorVitals {
            out vitals : VitalsData;
            out alarm : Boolean;
            first start;
            then action readSensors;
            then action evaluateLimits;
            then action generateAlarm;
            then done;
        }
    }
    
    part def AnesthesiaDeliverySystem {
        port anesCtrl : AnesthesiaPort;
        attribute currentFlowRate : FlowRate;
        attribute currentRespRate : RespiratoryRate;
        attribute currentTidalVolume : Volume;
        
        perform action manageAnesthesia {
            in flowRateCmd : FlowRate;
            in respRateCmd : RespiratoryRate;
            in tidalVolumeCmd : Volume;
            first start;
            then action setGasFlow;
            then action setVentilation;
            then done;
        }
    }
    
    part def SurgicalLightingSystem {
        port lightCtrl : LightingPort;
        attribute currentIntensity : LightIntensity;
        attribute currentColorTemp : ColorTemperature;
        attribute currentFocus : Angle;
        
        perform action adjustLighting {
            in intensityCmd : LightIntensity;
            in colorTempCmd : ColorTemperature;
            in focusCmd : Angle;
            first start;
            then action setIntensity;
            then action setColorTemp;
            then action setFocus;
            then done;
        }
    }
    
    part def EnvironmentalControlSystem {
        port envCtrl : EnvironmentalPort;
        attribute currentTemp : Temperature;
        attribute currentHumidity : Humidity;
        attribute currentPressure : Pressure;
        
        perform action maintainEnvironment {
            in tempCmd : Temperature;
            in humidityCmd : Humidity;
            out currentTemp : Temperature;
            out currentPressure : Pressure;
            first start;
            then action filterAir;
            then action controlTemp;
            then action maintainPressure;
            then done;
        }
    }
    
    part def DisplaySystem {
        port displayIn : DisplayPort;
        part screens[4];
        
        perform action displayData {
            in image : ImageData;
            in vitals : VitalsData;
            in overlay : InstrumentPosition;
            first start;
            then action renderImage;
            then action renderVitals;
            then action renderOverlay;
            then done;
        }
    }
    
    part def SurgicalNavigationSystem {
        port navOut : NavigationPort;
        part trackingCamera;
        part instrumentTracker;
        
        perform action trackInstrument {
            in refImage : ImageData;
            out position : InstrumentPosition;
            first start;
            then action detectInstrument;
            then action calculatePosition;
            then done;
        }
    }
    
    part def SystemController {
        port imgIn : ~ImagePort;
        port tablePort : ~TableControlPort;
        port vitalsPort : ~VitalsPort;
        port anesPort : ~AnesthesiaPort;
        port lightPort : ~LightingPort;
        port envPort : ~EnvironmentalPort;
        port dispPort : ~DisplayPort;
        port navPort : ~NavigationPort;
        
        perform action orchestrateProcedure {
            first start;
            then action positionPatient;
            then action administerAnesthesia;
            then action adjustLights;
            then action startMonitoring;
            then action performImaging;
            then action performNavigation;
            then action updateDisplay;
            then done;
        }
    }
    
    requirement def RadiationSafetyLimit {
        doc /* The total radiation dose delivered to the patient must not exceed 50 mGy per procedure. */
        attribute maxDose : RadiationDose = 50;
    }
    requirement def VitalSignsMonitoring {
        doc /* The system shall continuously monitor patient vital signs and generate alarms when vitals fall outside safe limits. */
    }
    requirement def EnvironmentalSterility {
        doc /* The environmental control system shall maintain sterile conditions with filtered air and positive pressure. */
    }
    requirement def ImageGuidanceAccuracy {
        doc /* The surgical navigation system shall accurately track instrument positions and overlay them on medical images. */
    }
    
    part def HybridOR {
        part imagingSystem : ImagingSystem;
        part surgicalTable : SurgicalTable;
        part patientMonitoringSystem : PatientMonitoringSystem;
        part anesthesiaDeliverySystem : AnesthesiaDeliverySystem;
        part surgicalLightingSystem : SurgicalLightingSystem;
        part environmentalControlSystem : EnvironmentalControlSystem;
        part displaySystem : DisplaySystem;
        part surgicalNavigationSystem : SurgicalNavigationSystem;
        part systemController : SystemController;
        
        connect imagingSystem.imgOut to systemController.imgIn;
        connect systemController.tablePort to surgicalTable.tableCtrl;
        connect patientMonitoringSystem.vitalsOut to systemController.vitalsPort;
        connect systemController.anesPort to anesthesiaDeliverySystem.anesCtrl;
        connect systemController.lightPort to surgicalLightingSystem.lightCtrl;
        connect systemController.envPort to environmentalControlSystem.envCtrl;
        connect systemController.dispPort to displaySystem.displayIn;
        connect systemController.navPort to surgicalNavigationSystem.navOut;
        
        satisfy RadiationSafetyLimit by imagingSystem;
        satisfy VitalSignsMonitoring by patientMonitoringSystem;
        satisfy EnvironmentalSterility by environmentalControlSystem;
        satisfy ImageGuidanceAccuracy by surgicalNavigationSystem;
    }
}
