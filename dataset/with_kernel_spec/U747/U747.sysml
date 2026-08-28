package LAPS_System {
    
    attribute def Voltage :> ScalarValues::Real { attribute unit : ScalarValues::String = "V"; }
    attribute def Current :> ScalarValues::Real { attribute unit : ScalarValues::String = "A"; }
    attribute def Concentration :> ScalarValues::Real { attribute unit : ScalarValues::String = "mol/L"; }
    attribute def Length :> ScalarValues::Real { attribute unit : ScalarValues::String = "m"; }
    attribute def Frequency :> ScalarValues::Real { attribute unit : ScalarValues::String = "Hz"; }
    
    item def Analyte {
        attribute pH : Concentration;
    }
    
    item def LightBeam {
        attribute modulationFrequency : Frequency;
        attribute intensity : ScalarValues::Real;
    }
    
    item def ScanPosition {
        attribute x : Length;
        attribute y : Length;
    }
    
    item def PhotocurrentSignal {
        attribute current : Current;
        attribute position : ScanPosition;
    }
    
    item def SurfacePotentialMap {
        attribute potentials : Voltage[0..*];
        attribute positions : ScanPosition[0..*];
    }
    
    item def CalibrationData {
        attribute slope : ScalarValues::Real;
        attribute intercept : Voltage;
    }
    
    item def StartMeasurement;
    
    part def SemiconductorSubstrate;
    part def InsulatingLayer;
    part def IonSensitiveMembrane;
    
    part def SensorChip {
        part substrate : SemiconductorSubstrate;
        part insulator : InsulatingLayer;
        part membrane : IonSensitiveMembrane;
        port referenceVoltageIn { in item v : Voltage; }
        port lightIn { in item light : LightBeam; }
        port photocurrentOut { out item signal : PhotocurrentSignal; }
    }
    
    part def LightSource {
        port lightOut { out item light : LightBeam; }
        port modulationRefOut { out item freq : Frequency; }
    }
    
    part def OpticalSystem {
        port lightIn { in item light : LightBeam; }
        port scanCmdIn { in item pos : ScanPosition; }
        port focusedLightOut { out item light : LightBeam; }
    }
    
    part def ScanningController {
        port scanCmdOut { out item pos : ScanPosition; }
    }
    
    part def ReferenceElectrode {
        port referenceVoltageOut { out item v : Voltage; }
    }
    
    part def PhotodetectionCircuit {
        port photocurrentIn { in item signal : PhotocurrentSignal; }
        port rawSignalOut { out item signal : PhotocurrentSignal; }
    }
    
    part def LockInAmplifier {
        port signalIn { in item signal : PhotocurrentSignal; }
        port referenceIn { in item freq : Frequency; }
        port amplifiedSignalOut { out item signal : PhotocurrentSignal; }
    }
    
    part def DataProcessor {
        port signalIn { in item signal : PhotocurrentSignal; }
        port calibrationIn { in item data : CalibrationData; }
        port mapOut { out item map : SurfacePotentialMap; }
        port concentrationOut { out item conc : Concentration; }
    }
    
    part def LAPS {
        part sensorChip : SensorChip;
        part lightSource : LightSource;
        part opticalSystem : OpticalSystem;
        part scanningController : ScanningController;
        part referenceElectrode : ReferenceElectrode;
        part photodetectionCircuit : PhotodetectionCircuit;
        part lockInAmplifier : LockInAmplifier;
        part dataProcessor : DataProcessor;
        
        connect lightSource.lightOut to opticalSystem.lightIn;
        connect opticalSystem.focusedLightOut to sensorChip.lightIn;
        connect scanningController.scanCmdOut to opticalSystem.scanCmdIn;
        connect referenceElectrode.referenceVoltageOut to sensorChip.referenceVoltageIn;
        connect sensorChip.photocurrentOut to photodetectionCircuit.photocurrentIn;
        connect photodetectionCircuit.rawSignalOut to lockInAmplifier.signalIn;
        connect lightSource.modulationRefOut to lockInAmplifier.referenceIn;
        connect lockInAmplifier.amplifiedSignalOut to dataProcessor.signalIn;
        
        state lapsStates : LAPS_States;
    }
    
    action def Initialize;
    action def Calibrate {
        out calibrationData : CalibrationData;
    }
    action def Measure {
        in scanArea : ScanPosition;
        out rawSignal : PhotocurrentSignal;
    }
    action def ProcessData {
        in rawSignal : PhotocurrentSignal;
        in calibrationData : CalibrationData;
        out map : SurfacePotentialMap;
        out concentration : Concentration;
    }
    
    state def LAPS_States {
        entry; then Initializing;
        state Initializing {
            do action Initialize;
        }
        transition first Initializing then Calibrating;
        state Calibrating {
            do action Calibrate;
        }
        transition first Calibrating then Ready;
        state Ready {
            accept StartMeasurement then Measuring;
        }
        state Measuring {
            do action Measure;
        }
        transition first Measuring then Processing;
        state Processing {
            do action ProcessData;
        }
        transition first Processing then Ready;
    }
    
    requirement def MeasurementAccuracy {
        subject laps : LAPS;
        objective {
            doc "The system shall measure ion concentration with an accuracy of +/- 0.01 pH."
        }
    }
    
    requirement def SpatialResolution {
        subject laps : LAPS;
        objective {
            doc "The system shall provide a 2D spatial resolution of at least 10 micrometers."
        }
    }
    
    requirement def ModulationFrequency {
        subject laps : LAPS;
        objective {
            doc "The light source shall be modulated at a frequency between 1 kHz and 100 kHz."
        }
    }
}
