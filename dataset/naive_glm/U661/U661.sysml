package PiezoelectricActuatorSystem {
    import ISQ::*;
    import ScalarValues::*;

    value type Voltage :> Real { unit 'V'; }
    value type Displacement :> Real { unit 'um'; }
    value type ElectricField :> Real { unit 'V/um'; }
    value type Current :> Real {> 'A'; }
    value type Frequency :> Real { unit 'Hz'; }
    value type Position :> Real { unit 'um'; }
    value type Gain :> Real { unit '1'; }
    value type Stiffness :> Real { unit 'N/um'; }
    value type Resistance :> Real { unit 'ohm'; }
    value type Capacitance :> Real { unit 'uF'; }
    value type ResponseTime :> Real { unit 'ms'; }

    item def VoltageSignal {
        attribute magnitude : Voltage;
        attribute frequency : Frequency;
        attribute enabled : Boolean;
    }

    item def DisplacementFeedback {
        attribute measured : Displacement;
        attribute timestamp : Time;
        attribute valid : Boolean;
    }

    item def PositionCommand {
        attribute target : Position;
        attribute maxRate : Real; // um/s
        attribute priority : Integer;
    }

    item def SafetyCommand {
        attribute emergencyShutdown : Boolean;
        attribute reason : String;
    }

    port def VoltagePort {
        out voltage : VoltageSignal;
        in current : Current;
    }

    port def DisplacementPort {
        out displacement : Displacement;
    }

    port def CommandPort {
        out command : PositionCommand;
    }

    port def FeedbackPort {
        out feedback : DisplacementFeedback;
    }

    port def SafetyPort {
        out safety : SafetyCommand;
    }

    part def Substrate {
        attribute material : String = "alumina";
        attribute stiffness : Stiffness = 250.0;
        attribute thickness : Real = 1.0;
        attribute thermalExpansion : Real;
    }

    part def Electrode {
        attribute material : String = "platinum";
        attribute resistance : Resistance = 0.05;
        attribute thickness : Real = 0.2;
        port voltagePort : VoltagePort;
    }

    part def PiezoelectricFilm {
        attribute material : String = "PZT";
        attribute thickness : Real = 50.0;
        attribute piezoConstant : Real = 0.025; // um/V
        attribute capacitance : Capacitance = 1.2;
        attribute maxField : ElectricField = 30.0;
        attribute maxDisplacement : Displacement = 25.0;

        port topElectrode : VoltagePort;
        port bottomElectrode : VoltagePort;
        port mechanicalOutput : DisplacementPort;

        attribute appliedVoltage : Voltage = 0.0;
        attribute currentDisplacement : Displacement = 0.0;
        attribute targetDisplacement : Displacement = 0.0;
        attribute fieldStrength : ElectricField = 0.0;

        compute updateDisplacement {
            in v : Voltage;
            out d : Displacement;
        }

        state def Lifecycle {
            entry; then Inactive;

            state Inactive {
                entry; 
            }
            state Charging {
                entry;
            }
            state Actuating {
                entry;
            }
            state Stabilized {
                entry;
            }
            state Relaxed {
                entry;
            }

            transition from Inactive to Charging
                when appliedVoltage > 0.0;
            transition from Charging to Actuating
                when currentDisplacement > 0.0;
            transition from Actuating to Stabilized
                when currentDisplacement >= targetDisplacement;
            transition from Stabilized to Relaxed
                when appliedVoltage == 0.0;
            transition from Relaxed to Inactive
                when currentDisplacement == 0.0;
        }
    }

    part def PiezoStack {
        part substrate : Substrate;
        part bottomElectrode : Electrode;
        part film : PiezoelectricFilm;
        part topElectrode : Electrode;

        connection voltageBottom connect bottomElectrode.voltagePort to film.bottomElectrode;
        connection voltageTop connect topElectrode.voltagePort to film.topElectrode;

        attribute totalThickness : Real;
    }

    part def VoltageDriver {
        attribute maxVoltage : Voltage = 1000.0;
        attribute bandwidth : Frequency = 10000.0;
        attribute gain : Gain = 1.0;
        attribute outputVoltage : Voltage = 0.0;
        attribute emergencyActive : Boolean = false;

        port commandIn : CommandPort;
        port voltageOut : VoltagePort;
        port safetyIn : SafetyPort;

        action def Drive {
            in target : Position;
            in shutdown : Boolean;
            out voltage : VoltageSignal;
        }

        action drive : Drive {
        }
    }

    part def DisplacementSensor {
        attribute sensorType : String = "capacitive";
        attribute resolution : Displacement = 0.001;
        attribute range : Displacement = 50.0;
        attribute sampleRate : Frequency = 20000.0;
        attribute noiseFloor : Displacement = 0.002;

        port mechanicalIn : DisplacementPort;
        port feedbackOut : FeedbackPort;

        action def Measure {
            in displacement : Displacement;
            out feedback : DisplacementFeedback;
        }

        action measure : Measure {
        }
    }

    part def ControlProcessor {
        attribute kp : Gain = 50.0;
        attribute ki : Gain = 200.0;
        attribute kd : Gain = 5.0;
        attribute setpoint : Position = 0.0;
        attribute measured : Position = 0.0;
        attribute error : Real = 0.0;
        attribute integral : Real = 0.0;
        attribute derivative : Real = 0.0;
        attribute loopRate : Frequency = 20000.0;
        attribute tolerance : Displacement = 0.01;

        port commandIn : CommandPort;
        port feedbackIn : FeedbackPort;
        port commandOut : CommandPort;
        port safetyOut : SafetyPort;

        action def ControlLoop {
            in target : Position;
            in measured : Position;
            out voltageCommand : Position;
            out shutdown : Boolean;
        }

        action controlLoop : ControlLoop {
        }
    }

    part def EmergencyController {
        attribute threshold : Voltage = 1100.0;
        attribute responseTime : ResponseTime = 0.1;
        attribute active : Boolean = false;

        port safetyOut : SafetyPort;
        port monitorIn : VoltagePort;

        action def Evaluate {
            in voltage : Voltage;
            out shutdown : Boolean;
        }

        action evaluate : Evaluate {
        }
    }

    part def PiezoActuatorSystem {
        part stack : PiezoStack;
        part driver : VoltageDriver;
        part sensor : DisplacementSensor;
        part processor : ControlProcessor;
        part emergency : EmergencyController;

        port externalCommand : CommandPort;
        port systemFeedback : FeedbackPort;

        connection cmdIn connect externalCommand to processor.commandIn;
        connection procToDriver connect processor.commandOut to driver.commandIn;
        connection driverToTopElectrode connect driver.voltageOut to stack.topElectrode.voltagePort;
        connection driverToBottomElectrode connect driver.voltageOut to stack.bottomElectrode.voltagePort;
        connection stackToSensor connect stack.film.mechanicalOutput to sensor.mechanicalIn;
        connection sensorToProc connect sensor.feedbackOut to processor.feedbackIn;
        connection sensorToSystem connect sensor.feedbackOut to systemFeedback;
        connection driverToEmergency connect driver.voltageOut to emergency.monitorIn;
        connection emergencyToDriver connect emergency.safetyOut to driver.safetyIn;
        connection emergencyToProc connect emergency.safetyOut to processor.safetyOut;

        attribute systemAccuracy : Displacement = 0.01;
        attribute systemBandwidth : Frequency = 5000.0;
    }

    requirement def PrecisionRequirement {
        subject actuator : PiezoActuatorSystem;
        attribute positioningAccuracy : Displacement = 0.01;
        require { actuator.systemAccuracy <= positioningAccuracy; }
    }

    requirement def ResponseTimeRequirement {
        subject actuator : PiezoActuatorSystem;
        attribute maxResponseTime : ResponseTime = 1.0;
        require { actuator.systemBandwidth >= 1000.0; }
    }

    requirement def SafetyRequirement {
        subject actuator : PiezoActuatorSystem;
        attribute maxShutdownTime : ResponseTime = 0.1;
        attribute maxVoltage : Voltage = 1000.0;
        require { actuator.emergency.responseTime <= maxShutdownTime; }
        require { actuator.driver.maxVoltage <= maxVoltage; }
    }

    requirement def LifecycleRequirement {
        subject film : PiezoelectricFilm;
        require { film.Lifecycle.Inactive exists; }
        require { film.Lifecycle.Charging exists; }
        require { film.Lifecycle.Actuating exists; }
        require { film.Lifecycle.Stabilized exists; }
        require { film.Lifecycle.Relaxed exists; }
    }

    requirement def ClosedLoopRequirement {
        subject actuator : PiezoActuatorSystem;
        require { actuator.processor.feedbackIn connected; }
        require { actuator.sensor.feedbackOut connected; }
        require { actuator.driver.commandIn connected; }
    }

    satisfaction satisfyPrecision by PiezoActuatorSystem : PrecisionRequirement;
    satisfaction satisfyResponse by PiezoActuatorSystem : ResponseTimeRequirement;
    satisfaction satisfySafety by PiezoActuatorSystem : SafetyRequirement;
    satisfaction satisfyLifecycle by PiezoActuatorSystem.stack.film : LifecycleRequirement;
    satisfaction satisfyClosedLoop by PiezoActuatorSystem : ClosedLoopRequirement;
}
