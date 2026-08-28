package NDIRGasSensor {
    import ScalarValues::*;
    import SI::*;

    // ---------- Value Types ----------
    value def ConcentrationPPM :> Real {
        doc "Gas concentration in parts per million.";
        attribute unit : String = "ppm";
    }
    value def IrradianceValue :> Real {
        doc "Infrared light intensity.";
        attribute unit : String = "W/m^2";
    }
    value def SignalVoltage :> Real {
        doc "Detector output voltage.";
        attribute unit : String = "V";
    }
    value def OperatingTemperature :> Real {
        doc "Operating temperature of the emitter.";
        attribute unit : String = "K";
    }
    value def TimeStampSeconds :> Real {
        doc "Time stamp in seconds since power-on.";
        attribute unit : String = "s";
    }
    value def WavelengthValue :> Real {
        doc "Wavelength of infrared light.";
        attribute unit : String = "nm";
    }
    value def PathLength :> Real {
        doc "Optical path length.";
        attribute unit : String = "mm";
    }
    value def DurationSeconds :> Real {
        doc "Duration in seconds.";
        attribute unit : String = "s";
    }

    // ---------- Items ----------
    item def InfraredBeam {
        attribute wavelength : WavelengthValue;
        attribute intensity : IrradianceValue;
    }
    item def FilteredBeam :> InfraredBeam;
    item def MeasurementBeam :> InfraredBeam;
    item def ReferenceBeam :> InfraredBeam;

    item def GasSample {
        attribute targetGas : String;
        attribute concentration : ConcentrationPPM;
        attribute temperature : OperatingTemperature;
    }

    item def MeasurementData {
        attribute concentration : ConcentrationPPM;
        attribute timestamp : TimeStampSeconds;
        attribute status : String;
    }

    // ---------- Port Definitions ----------
    port def OpticalOutPort {
        out item beam : InfraredBeam;
    }
    port def OpticalInPort {
        in item beam : InfraredBeam;
    }
    port def GasInletPort {
        in item sample : GasSample;
    }
    port def GasOutletPort {
        out item sample : GasSample;
    }
    port def ElectricalOutPort {
        out attribute voltage : SignalVoltage;
    }
    port def ElectricalInPort {
        in attribute voltage : SignalVoltage;
    }
    port def DataOutPort {
        out item data : MeasurementData;
    }
    port def PowerInPort {
        in attribute supplyVoltage : SignalVoltage;
    }

    // ---------- Part Definitions ----------
    part def InfraredEmitter {
        attribute targetWavelength : WavelengthValue = 4300;
        attribute operatingTemperature : OperatingTemperature = 1100;
        attribute warmUpTime : DurationSeconds = 60;
        port opticalOut : OpticalOutPort;

        action def emit {
            out beam : InfraredBeam;
        }
        perform action emitAction : emit {
            out beam = opticalOut.beam;
        }
    }

    part def OpticalFilter {
        attribute centerWavelength : WavelengthValue = 4260;
        attribute bandwidth : WavelengthValue = 100;
        port opticalIn : OpticalInPort;
        port opticalOut : OpticalOutPort;

        action def filter {
            in inBeam : InfraredBeam;
            out outBeam : FilteredBeam;
        }
        perform action filterAction : filter {
            in inBeam = opticalIn.beam;
            out outBeam = opticalOut.beam;
        }
    }

    part def BeamSplitter {
        attribute splitRatio : Real = 0.5;
        port opticalIn : OpticalInPort;
        port measurementOut : OpticalOutPort;
        port referenceOut : OpticalOutPort;

        action def split {
            in inBeam : InfraredBeam;
            out measBeam : MeasurementBeam;
            out refBeam : ReferenceBeam;
        }
        perform action splitAction : split {
            in inBeam = opticalIn.beam;
            out measBeam = measurementOut.beam;
            out refBeam = referenceOut.beam;
        }
    }

    part def GasMeasurementChamber {
        attribute pathLength : PathLength = 50;
        port inlet : GasInletPort;
        port outlet : GasOutletPort;
        port opticalIn : OpticalInPort;
        port opticalOut : OpticalOutPort;

        action def absorb {
            in inBeam : InfraredBeam;
            in sample : GasSample;
            out outBeam : InfraredBeam;
        }
        perform action absorbAction : absorb {
            in inBeam = opticalIn.beam;
            in sample = inlet.sample;
            out outBeam = opticalOut.beam;
        }
    }

    part def MeasurementPhotodetector {
        attribute responsivity : Real = 1.0;
        port opticalIn : OpticalInPort;
        port electricalOut : ElectricalOutPort;

        action def convert {
            in beam : InfraredBeam;
            out voltage : SignalVoltage;
        }
        perform action convertAction : convert {
            in beam = opticalIn.beam;
            out voltage = electricalOut.voltage;
        }
    }

    part def ReferenceDetector {
        attribute responsivity : Real = 1.0;
        port opticalIn : OpticalInPort;
        port electricalOut : ElectricalOutPort;

        action def convert {
            in beam : InfraredBeam;
            out voltage : SignalVoltage;
        }
        perform action convertAction : convert {
            in beam = opticalIn.beam;
            out voltage = electricalOut.voltage;
        }
    }

    part def SignalProcessingUnit {
        attribute calibrationFactor : Real = 1.0;
        attribute measurementRange : ConcentrationPPM = 5000;
        port measurementIn : ElectricalInPort;
        port referenceIn : ElectricalInPort;
        port dataOut : DataOutPort;

        action def computeConcentration {
            in measVoltage : SignalVoltage;
            in refVoltage : SignalVoltage;
            out data : MeasurementData;
        }
        perform action computeAction : computeConcentration {
            in measVoltage = measurementIn.voltage;
            in refVoltage = referenceIn.voltage;
            out data = dataOut.data;
        }
    }

    // ---------- Composite Sensor ----------
    part def NDIRSensor {
        attribute targetGas : String = "CO2";
        attribute measurementRange : ConcentrationPPM = 5000;
        attribute maintenanceRequested : Boolean = false;
        attribute maintenanceComplete : Boolean = false;

        port gasInlet : GasInletPort;
        port gasOutlet : GasOutletPort;
        port dataOut : DataOutPort;
        port powerIn : PowerInPort;

        part emitter : InfraredEmitter;
        part filter : OpticalFilter;
        part splitter : BeamSplitter;
        part chamber : GasMeasurementChamber;
        part measDetector : MeasurementPhotodetector;
        part refDetector : ReferenceDetector;
        part processor : SignalProcessingUnit;

        connection opt1 connect emitter.opticalOut to filter.opticalIn;
        connection opt2 connect filter.opticalOut to splitter.opticalIn;
        connection opt3 connect splitter.measurementOut to chamber.opticalIn;
        connection opt4 connect chamber.opticalOut to measDetector.opticalIn;
        connection opt5 connect splitter.referenceOut to refDetector.opticalIn;
        connection gas1 connect gasInlet to chamber.inlet;
        connection gas2 connect chamber.outlet to gasOutlet;
        connection elec1 connect measDetector.electricalOut to processor.measurementIn;
        connection elec2 connect refDetector.electricalOut to processor.referenceIn;
        connection data1 connect processor.dataOut to dataOut;

        exhibit state lifecycle : SensorLifecycle;
    }

    // ---------- State Machine ----------
    state def SensorLifecycle {
        state PoweredOff {
            doc "Sensor is powered off.";
        }
        state Initializing {
            doc "Sensor performs internal initialization routines.";
        }
        state WarmUp {
            doc "Infrared emitter warms to stable operating temperature.";
        }
        state Calibrating {
            doc "Sensor performs calibration sequence using reference beam.";
        }
        state Measuring {
            doc "Continuous measurement mode.";
        }
        state Maintenance {
            doc "Sensor in maintenance mode.";
        }
        state ErrorState {
            doc "Sensor in error condition.";
        }

        transition t_off_to_init
            from PoweredOff to Initializing
            when powerIn.supplyVoltage > 0;
        transition t_init_to_warmup
            from Initializing to WarmUp
            after 2 [DurationSeconds];
        transition t_warmup_to_cal
            from WarmUp to Calibrating
            when emitter.operatingTemperature >= 1100;
        transition t_cal_to_measure
            from Calibrating to Measuring
            after 5 [DurationSeconds];
        transition t_measure_to_error
            from Measuring to ErrorState
            when measDetector.electricalOut.voltage < 0;
        transition t_measure_to_maint
            from Measuring to Maintenance
            when maintenanceRequested == true;
        transition t_maint_to_measure
            from Maintenance to Measuring
            when maintenanceComplete == true;
        transition t_error_to_off
            from ErrorState to PoweredOff
            when powerIn.supplyVoltage == 0;
    }

    // ---------- Requirements ----------
    requirement def MeasurementAccuracy {
        subject ndirSensor : NDIRSensor;
        objective {
            doc "The sensor shall measure CO2 concentration with an accuracy of ±50 ppm over the range 0 to 5000 ppm.";
        }
        assume {
            ndirSensor.targetGas == "CO2"
        }
    }

    requirement def WarmUpStability {
        subject emitter : InfraredEmitter;
        objective {
            doc "The infrared emitter shall reach a stable operating temperature within 60 seconds of power-on.";
        }
    }

    requirement def DualBeamCompensation {
        subject ndirSensor : NDIRSensor;
        objective {
            doc "The sensor shall use a reference beam to compensate for fluctuations and degradation in the infrared emitter output.";
        }
    }

    requirement def DataOutputRequirement {
        subject processor : SignalProcessingUnit;
        objective {
            doc "The processor shall output a concentration value in ppm together with a timestamp.";
        }
    }

    requirement def LifecycleRequirement {
        subject ndirSensor : NDIRSensor;
        objective {
            doc "The sensor shall implement the operational states: PoweredOff, Initializing, WarmUp, Calibrating, Measuring, Maintenance, and ErrorState.";
        }
    }

    requirement def GasFlowRequirement {
        subject chamber : GasMeasurementChamber;
        objective {
            doc "The gas measurement chamber shall allow the sample gas to flow through an inlet and an outlet.";
        }
    }

    requirement def WavelengthIsolation {
        subject filter : OpticalFilter;
        objective {
            doc "The optical filter shall isolate the characteristic absorption wavelength of the target gas.";
        }
    }

    // ---------- Requirement Satisfaction ----------
    satisfaction satisfy MeasurementAccuracy by ndirSensor.processor.computeAction;
    satisfaction satisfy WarmUpStability by ndirSensor.emitter;
    satisfaction satisfy DualBeamCompensation by ndirSensor.splitter;
    satisfaction satisfy DataOutputRequirement by ndirSensor.processor;
    satisfaction satisfy LifecycleRequirement by ndirSensor.lifecycle;
    satisfaction satisfy GasFlowRequirement by ndirSensor.chamber;
    satisfaction satisfy WavelengthIsolation by ndirSensor.filter;
}
