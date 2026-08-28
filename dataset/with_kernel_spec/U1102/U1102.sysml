package InfraredSensorSystem {
    private import ISQ::*;
    private import ScalarValues::*;
    
    item def InfraredRadiation;
    item def FocusedRadiation;
    item def RawElectricalSignal;
    item def TemperatureMap;
    item def ThermalImage;
    item def ElectricalPower;
    
    item def PowerOnSignal;
    item def TempReachedSignal;
    item def CalCompleteSignal;
    item def CaptureCommand;
    item def ImageCapturedSignal;
    
    port def RadiationInPort {
        in item radiation : InfraredRadiation;
    }
    port def FocusedRadiationOutPort {
        out item focusedRadiation : FocusedRadiation;
    }
    port def FocusedRadiationInPort {
        in item focusedRadiation : FocusedRadiation;
    }
    port def RawSignalOutPort {
        out item rawSignal : RawElectricalSignal;
    }
    port def RawSignalInPort {
        in item rawSignal : RawElectricalSignal;
    }
    port def TempMapOutPort {
        out item tempMap : TemperatureMap;
    }
    port def TempMapInPort {
        in item tempMap : TemperatureMap;
    }
    port def ThermalImageOutPort {
        out item thermalImage : ThermalImage;
    }
    port def PowerPort {
        inout item power : ElectricalPower;
    }
    
    action def FocusRadiation {
        in item radiation : InfraredRadiation;
        out item focusedRadiation : FocusedRadiation;
    }
    action def ConvertRadiation {
        in item focusedRadiation : FocusedRadiation;
        out item rawSignal : RawElectricalSignal;
    }
    action def ProcessSignals {
        in item rawSignal : RawElectricalSignal;
        out item tempMap : TemperatureMap;
    }
    action def FormImage {
        in item tempMap : TemperatureMap;
        out item thermalImage : ThermalImage;
    }
    action def CoolDetector {
        attribute targetTemp :> ISQ::temperature;
    }
    action def DistributePower {
        in item power : ElectricalPower;
        out item opticalPower : ElectricalPower;
        out item coolerPower : ElectricalPower;
        out item sppPower : ElectricalPower;
        out item ifmPower : ElectricalPower;
    }
    action def Initialize {
        action cool : CoolDetector;
    }
    action def Calibrate;
    action def CaptureImage {
        in item scene : InfraredRadiation;
        out item image : ThermalImage;
        action focus : FocusRadiation {
            in item radiation = CaptureImage::scene;
            out item focusedRadiation;
        }
        flow from focus.focusedRadiation to convert.focusedRadiation;
        action convert : ConvertRadiation {
            in item focusedRadiation;
            out item rawSignal;
        }
        flow from convert.rawSignal to process.rawSignal;
        action process : ProcessSignals {
            in item rawSignal;
            out item tempMap;
        }
        flow from process.tempMap to form.tempMap;
        action form : FormImage {
            in item tempMap;
            out item thermalImage = CaptureImage::image;
        }
    }
    
    state def SystemStates {
        entry; then off;
        state off;
        transition off_to_initializing
            first off
            accept PowerOnSignal
            then initializing;
        state initializing;
        transition init_to_calib
            first initializing
            accept TempReachedSignal
            then calibrating;
        state calibrating;
        transition calib_to_ready
            first calibrating
            accept CalCompleteSignal
            then ready;
        state ready;
        transition ready_to_capturing
            first ready
            accept CaptureCommand
            then capturing;
        state capturing;
        transition capturing_to_ready
            first capturing
            accept ImageCapturedSignal
            then ready;
    }
    
    part def OpticalSystem {
        attribute focalLength :> ISQ::length;
        port radiationIn : RadiationInPort;
        port radiationOut : FocusedRadiationOutPort;
        port powerIn : PowerPort;
        perform action focusRadiation : FocusRadiation;
    }
    part def FocalPlaneArray {
        attribute operatingTemperature :> ISQ::temperature;
        attribute detectorElements : ScalarValues::Integer;
        port radiationIn : FocusedRadiationInPort;
        port signalOut : RawSignalOutPort;
        port powerIn : PowerPort;
        perform action convertRadiation : ConvertRadiation;
    }
    part def CryogenicCooler {
        attribute targetTemperature :> ISQ::temperature = 77.0;
        port powerIn : PowerPort;
        perform action coolDetector : CoolDetector;
    }
    part def SignalProcessingUnit {
        port signalIn : RawSignalInPort;
        port dataOut : TempMapOutPort;
        port powerIn : PowerPort;
        perform action processSignals : ProcessSignals;
    }
    part def ImageFormationModule {
        port dataIn : TempMapInPort;
        port powerIn : PowerPort;
        port imageOut : ThermalImageOutPort;
        perform action formImage : FormImage;
    }
    part def PowerManagementUnit {
        port externalPowerIn : PowerPort;
        port opticalPowerOut : PowerPort;
        port coolerPowerOut : PowerPort;
        port sppPowerOut : PowerPort;
        port ifmPowerOut : PowerPort;
        perform action distributePower : DistributePower;
    }
    part def InfraredSensorSystem {
        port externalPower : PowerPort;
        port sceneInput : RadiationInPort;
        port imageOutput : ThermalImageOutPort;
        
        part opticalSystem : OpticalSystem;
        part focalPlaneArray : FocalPlaneArray;
        part cryogenicCooler : CryogenicCooler;
        part signalProcessingUnit : SignalProcessingUnit;
        part imageFormationModule : ImageFormationModule;
        part powerManagementUnit : PowerManagementUnit;

        connect externalPower to powerManagementUnit.externalPowerIn;
        connect sceneInput to opticalSystem.radiationIn;
        
        connect powerManagementUnit.opticalPowerOut to opticalSystem.powerIn;
        connect powerManagementUnit.coolerPowerOut to cryogenicCooler.powerIn;
        connect powerManagementUnit.sppPowerOut to signalProcessingUnit.powerIn;
        connect powerManagementUnit.ifmPowerOut to imageFormationModule.powerIn;

        connect opticalSystem.radiationOut to focalPlaneArray.radiationIn;
        connect focalPlaneArray.signalOut to signalProcessingUnit.signalIn;
        connect signalProcessingUnit.dataOut to imageFormationModule.dataIn;
        connect imageFormationModule.imageOut to imageOutput;

        exhibit state systemStates : SystemStates;
        perform action initialize : Initialize;
        perform action calibrate : Calibrate;
        perform action captureImage : CaptureImage;

        assert constraint {
            focalPlaneArray.operatingTemperature <= cryogenicCooler.targetTemperature
        }
    }
    
    requirement def CryogenicTempRequirement {
        doc /* The Focal Plane Array shall be maintained at or below 77 Kelvin during operation. */
        attribute maxTemp :> ISQ::temperature = 77.0;
    }
    requirement def ImageResolutionRequirement {
        doc /* The sensor shall have a minimum detector resolution of 640 elements. */
        attribute minResolution : ScalarValues::Integer = 640;
    }
    requirement def PowerDistributionRequirement {
        doc /* The Power Management Unit shall distribute electrical power to all active subsystems. */
    }
    requirement def CaptureSequenceRequirement {
        doc /* Image capture shall only occur after initialization and calibration are complete. */
    }
    
    part irSensor : InfraredSensorSystem {
        satisfy CryogenicTempRequirement by focalPlaneArray;
        satisfy ImageResolutionRequirement by focalPlaneArray;
        satisfy PowerDistributionRequirement by powerManagementUnit;
        satisfy CaptureSequenceRequirement by captureImage;
    }
}
