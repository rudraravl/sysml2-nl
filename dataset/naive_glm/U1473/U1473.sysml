package PressureRegulationSystem {
    import ISQ::*;
    import ScalarValues::*;

    // ---- Value Types with Units ----
    value def PressureValue :> Real {
        :>> unit = 'kPa';
    }
    value def VolumeValue :> Real {
        :>> unit = 'L';
    }
    value def FlowRateValue :> Real {
        :>> unit = 'L/min';
    }
    value def ValvePosition :> Real {
        :>> unit = '%';
        :>> min = 0;
        :>> max = 100;
    }

    // ---- Item Types ----
    item def Fluid;
    item def PressureReading {
        attribute value : PressureValue;
    }
    item def ValveCommand {
        attribute position : ValvePosition;
    }
    item def EmergencyCommand {
        attribute shutdownInitiated : Boolean;
    }

    // ---- Port Definitions ----
    port def FluidPort {
        out item fluid : Fluid;
        in item fluidIn : Fluid;
    }
    port def PressureSignalPort {
        out item reading : PressureReading;
    }
    port def CommandPort {
        out item command : ValveCommand;
        out item emergency : EmergencyCommand;
    }
    port def ReliefVentPort {
        out item ventedFluid : Fluid;
    }

    // ---- Pressure Vessel ----
    part def PressureVessel {
        attribute capacity : VolumeValue = 500 [L];
        attribute maxOperatingPressure : PressureValue = 1000 [kPa];
        attribute reliefThreshold : PressureValue = 950 [kPa];
        attribute currentPressure : PressureValue;
        attribute targetPressure : PressureValue = 500 [kPa];
        attribute tolerance : PressureValue = 5 [kPa];

        port inlet : FluidPort;
        port outlet : FluidPort;
        port sensorTap : FluidPort;
        port reliefPort : FluidPort;

        action def UpdatePressure {
            in inflow : FlowRateValue;
            in outflow : FlowRateValue;
            out newPressure : PressureValue;
        }
    }

    // ---- Pressure Sensor ----
    part def PressureSensor {
        attribute samplingRate : Real = 10 [1/min];
        attribute measuredPressure : PressureValue;

        port fluidConnection : FluidPort;
        port signalOut : PressureSignalPort;

        action def SamplePressure {
            in fluidPressure : PressureValue;
            out reading : PressureReading;
        }
    }

    // ---- Inlet Control Valve ----
    part def InletControlValve {
        attribute position : ValvePosition = 0 [%];
        attribute maxFlowRate : FlowRateValue = 50 [L/min];

        port supplyIn : FluidPort;
        port vesselOut : FluidPort;
        port commandIn : CommandPort;

        action def AdjustPosition {
            in commandedPosition : ValvePosition;
            out actualPosition : ValvePosition;
            out flowRate : FlowRateValue;
        }
    }

    // ---- Relief Valve ----
    part def ReliefValve {
        attribute setPressure : PressureValue = 950 [kPa];
        attribute isOpen : Boolean = false;
        attribute ventFlowRate : FlowRateValue = 100 [L/min];

        port vesselConnection : FluidPort;
        port vent : ReliefVentPort;

        action def CheckPressure {
            in sensedPressure : PressureValue;
            out openState : Boolean;
        }
    }

    // ---- Pressure Controller ----
    part def PressureController {
        attribute targetPressure : PressureValue = 500 [kPa];
        attribute tolerance : PressureValue = 5 [kPa];
        attribute emergencyThreshold : PressureValue = 950 [kPa];
        attribute proportionalGain : Real = 0.5;
        attribute integralGain : Real = 0.1;
        attribute integralError : Real = 0;
        attribute measuredPressure : PressureValue;
        attribute computedPosition : ValvePosition;

        port sensorIn : PressureSignalPort;
        port valveCommandOut : CommandPort;

        action def ComputeError {
            in measured : PressureValue;
            in target : PressureValue;
            out error : Real;
        }

        action def ComputeValvePosition {
            in error : Real;
            in pGain : Real;
            in iGain : Real;
            in prevIntegral : Real;
            out position : ValvePosition;
            out newIntegral : Real;
        }

        state machine def ControllerStates {
            state Setup {
                entry action {
                    attribute measuredPressure = 0 [kPa];
                    attribute computedPosition = 0 [%];
                }
                transition Setup to Monitoring
                    when (attribute measuredPressure > 0 [kPa]) {}
            }
            state Monitoring {
                entry action {
                    attribute computedPosition = 0 [%];
                }
                do action {
                    // Passive: pressure within tolerance
                }
                transition Monitoring to Regulating
                    when (abs(attribute measuredPressure - attribute targetPressure) > attribute tolerance) {}
                transition Monitoring to Emergency
                    when (attribute measuredPressure >= attribute emergencyThreshold) {}
            }
            state Regulating {
                do action {
                    // Compute error and adjust valve position
                }
                transition Regulating to Monitoring
                    when (abs(attribute measuredPressure - attribute targetPressure) <= attribute tolerance) {}
                transition Regulating to Emergency
                    when (attribute measuredPressure >= attribute emergencyThreshold) {}
            }
            state Emergency {
                entry action {
                    attribute computedPosition = 0 [%];
                    // Command inlet valve to shut completely
                    // Initiate system shutdown
                }
                do action {
                    // Hold inlet valve closed
                }
            }
            transition initial to Setup {}
        }
    }

    // ---- System Assembly ----
    part def AutomatedPressureRegulationSystem {
        part vessel : PressureVessel {
            :>> currentPressure = 500 [kPa];
        }
        part sensor : PressureSensor;
        part controller : PressureController;
        part inletValve : InletControlValve;
        part reliefValve : ReliefValve;

        connection fluidSupplyToValve : FluidFlow {
            :>> source :>> fluid = inletValve.vesselOut.fluid;
            :>> target :>> fluidIn = vessel.inlet.fluidIn;
        }
        connection vesselToSensor : FluidFlow {
            :>> source :>> fluid = vessel.sensorTap.fluid;
            :>> target :>> fluidIn = sensor.fluidConnection.fluidIn;
        }
        connection sensorToController : SignalFlow {
            :>> source :>> reading = sensor.signalOut.reading;
            :>> target :>> reading = controller.sensorIn.reading;
        }
        connection controllerToValve : CommandFlow {
            :>> source :>> command = controller.valveCommandOut.command;
            :>> target :>> command = inletValve.commandIn.command;
        }
        connection vesselToRelief : FluidFlow {
            :>> source :>> fluid = vessel.reliefPort.fluid;
            :>> target :>> fluidIn = reliefValve.vesselConnection.fluidIn;
        }

        connection def FluidFlow {
            end source : FluidPort;
            end target : FluidPort;
        }
        connection def SignalFlow {
            end source : PressureSignalPort;
            end target : PressureSignalPort;
        }
        connection def CommandFlow {
            end source : CommandPort;
            end target : CommandPort;
        }
    }

    // ---- Requirements ----
    requirement def MaintainTargetPressure {
        attribute target : PressureValue = 500 [kPa];
        attribute tolerance : PressureValue = 5 [kPa];
        subject : AutomatedPressureRegulationSystem;
        objective {
            assert abs(vessel.currentPressure - target) <= tolerance
        }
    }

    requirement def VesselCapacity {
        attribute requiredCapacity : VolumeValue = 500 [L];
        subject : PressureVessel;
        objective {
            assert vessel.capacity >= requiredCapacity
        }
    }

    requirement def MaxOperatingPressure {
        attribute maxPressure : PressureValue = 1000 [kPa];
        subject : PressureVessel;
        objective {
            assert vessel.maxOperatingPressure >= maxPressure
        }
    }

    requirement def ReliefValveActivation {
        attribute threshold : PressureValue = 950 [kPa];
        subject : ReliefValve;
        objective {
            assert reliefValve.setPressure == threshold
        }
    }

    requirement def EmergencyShutdown {
        attribute emergencyThreshold : PressureValue = 950 [kPa];
        subject : PressureController;
        objective {
            assert controller.emergencyThreshold == emergencyThreshold
        }
    }

    requirement def SystemRequirements {
        satisfy vesselCapacity : VesselCapacity by vessel;
        satisfy maxPressure : MaxOperatingPressure by vessel;
        satisfy reliefActivation : ReliefValveActivation by reliefValve;
        satisfy emergencyResponse : EmergencyShutdown by controller;
        satisfy pressureControl : MaintainTargetPressure by AutomatedPressureRegulationSystem;
    }
}
