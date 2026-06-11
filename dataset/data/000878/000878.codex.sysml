package FoamPumpSubsystemModel {
    import ScalarValues::*;
    import ISQ::*;
    import SI::*;

    attribute def Pressure :> ISQ::pressure {
        unit = SI::pascal;
    }

    attribute def FlowRate :> ISQ::volumeFlowRate {
        unit = SI::litre / SI::minute;
    }

    attribute def Volume :> ISQ::volume {
        unit = SI::litre;
    }

    attribute def Temperature :> ISQ::thermodynamicTemperature {
        unit = SI::degreeCelsius;
    }

    attribute def RotationalSpeed :> ISQ::frequency {
        unit = SI::revolution / SI::minute;
    }

    attribute def Power :> ISQ::power {
        unit = SI::watt;
    }

    attribute def Voltage :> ISQ::electricPotential {
        unit = SI::volt;
    }

    attribute def Current :> ISQ::electricCurrent {
        unit = SI::ampere;
    }

    attribute def Efficiency :> ScalarValues::Real {
        :>> range = "0.0..1.0";
    }

    attribute def FoamExpansionRatio :> ScalarValues::Real {
        :>> range = "1.0..30.0";
    }

    attribute def LiquidLevel :> ScalarValues::Real {
        :>> range = "0.0..1.0";
    }

    attribute def CommandState :> ScalarValues::String;
    attribute def FaultCode :> ScalarValues::String;

    item def FoamSolution {
        attribute waterFraction : ScalarValues::Real;
        attribute concentrateFraction : ScalarValues::Real;
        attribute airFraction : ScalarValues::Real;
        attribute temperature : Temperature;
        attribute expansionRatio : FoamExpansionRatio;
        attribute viscosity : ScalarValues::Real;
    }

    item def ElectricalPower {
        attribute voltage : Voltage;
        attribute current : Current;
        attribute power : Power;
    }

    item def ControlSignal {
        attribute command : CommandState;
        attribute requestedFlow : FlowRate;
        attribute requestedPressure : Pressure;
    }

    item def SensorSignal {
        attribute measuredFlow : FlowRate;
        attribute measuredPressure : Pressure;
        attribute measuredTemperature : Temperature;
        attribute measuredLevel : LiquidLevel;
        attribute faultCode : FaultCode;
    }

    port def FluidInletPort {
        in item incomingFoamSolution : FoamSolution;
        attribute inletPressure : Pressure;
    }

    port def FluidOutletPort {
        out item outgoingFoamSolution : FoamSolution;
        attribute outletPressure : Pressure;
        attribute outletFlow : FlowRate;
    }

    port def PowerPort {
        in item suppliedPower : ElectricalPower;
    }

    port def CommandPort {
        in item commandSignal : ControlSignal;
    }

    port def TelemetryPort {
        out item telemetrySignal : SensorSignal;
    }

    port def DrainPort {
        out item drainedFoamSolution : FoamSolution;
    }

    part def FoamPump {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        attribute ratedFlow : FlowRate = 120 [SI::litre / SI::minute];
        attribute ratedDischargePressure : Pressure = 650000 [SI::pascal];
        attribute maximumDischargePressure : Pressure = 850000 [SI::pascal];
        attribute minimumSuctionPressure : Pressure = 50000 [SI::pascal];
        attribute ratedSpeed : RotationalSpeed = 1750 [SI::revolution / SI::minute];
        attribute motorPowerRating : Power = 2200 [SI::watt];
        attribute hydraulicEfficiency : Efficiency = 0.72;
        attribute currentSpeed : RotationalSpeed;
        attribute currentFlow : FlowRate;
        attribute currentPressure : Pressure;
        attribute enabled : ScalarValues::Boolean;
        attribute faulted : ScalarValues::Boolean;

        action pumpFoam {
            in item suctionFluid : FoamSolution;
            in requestedFlow : FlowRate;
            in requestedPressure : Pressure;
            out item dischargedFluid : FoamSolution;
            out deliveredFlow : FlowRate;
            out deliveredPressure : Pressure;

            first startMotor;
            then drawFluid;
            then pressurizeFluid;
            then dischargeFluid;

            action startMotor {
                out speed : RotationalSpeed;
            }

            action drawFluid {
                in item inletFluid : FoamSolution = suctionFluid;
                out item meteredFluid : FoamSolution;
            }

            action pressurizeFluid {
                in item meteredFluid : FoamSolution;
                out item pressurizedFluid : FoamSolution;
                out pressure : Pressure;
            }

            action dischargeFluid {
                in item pressurizedFluid : FoamSolution;
                out item outletFluid : FoamSolution = dischargedFluid;
                out flow : FlowRate = deliveredFlow;
            }
        }

        state def PumpOperatingState {
            entry action initializePump;
            state Off;
            state Priming;
            state Running;
            state Standby;
            state Faulted;
            state Shutdown;

            transition initial then Off;

            transition Off_to_Priming
                first Off
                accept ControlSignal
                if command == "START"
                then Priming;

            transition Priming_to_Running
                first Priming
                if inlet.inletPressure >= minimumSuctionPressure
                then Running;

            transition Priming_to_Faulted
                first Priming
                if inlet.inletPressure < minimumSuctionPressure
                then Faulted;

            transition Running_to_Standby
                first Running
                accept ControlSignal
                if command == "STANDBY"
                then Standby;

            transition Standby_to_Running
                first Standby
                accept ControlSignal
                if command == "START"
                then Running;

            transition Running_to_Faulted
                first Running
                if currentPressure > maximumDischargePressure
                then Faulted;

            transition Running_to_Shutdown
                first Running
                accept ControlSignal
                if command == "STOP"
                then Shutdown;

            transition Standby_to_Shutdown
                first Standby
                accept ControlSignal
                if command == "STOP"
                then Shutdown;

            transition Shutdown_to_Off
                first Shutdown
                then Off;

            transition Faulted_to_Off
                first Faulted
                accept ControlSignal
                if command == "RESET"
                then Off;
        }

        requirement pumpPressureCapability {
            id = "FPS-PUMP-001";
            text = "The foam pump shall deliver at least 650 kPa discharge pressure at rated flow when supplied with adequate suction pressure.";
            require constraint {
                currentFlow >= ratedFlow implies currentPressure >= ratedDischargePressure;
            }
        }

        requirement pumpDryRunProtection {
            id = "FPS-PUMP-002";
            text = "The foam pump shall enter the Faulted state when suction pressure is below the minimum suction pressure during priming or running.";
            require constraint {
                inlet.inletPressure < minimumSuctionPressure implies faulted == true;
            }
        }
    }

    part def FoamReservoir {
        port outlet : FluidOutletPort;
        port drain : DrainPort;
        port telemetryOutput : TelemetryPort;

        attribute capacity : Volume = 250 [SI::litre];
        attribute usableVolume : Volume = 230 [SI::litre];
        attribute currentVolume : Volume;
        attribute level : LiquidLevel;
        attribute solutionTemperature : Temperature;
        attribute lowLevelThreshold : LiquidLevel = 0.15;
        attribute concentrateFraction : ScalarValues::Real = 0.03;

        requirement reservoirCapacityRequirement {
            id = "FPS-RES-001";
            text = "The reservoir shall store at least 230 liters of usable foam solution.";
            require constraint {
                usableVolume >= 230 [SI::litre];
            }
        }
    }

    part def SuctionFilter {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute meshSizeMicron : ScalarValues::Real = 500;
        attribute maximumPressureDrop : Pressure = 25000 [SI::pascal];
        attribute actualPressureDrop : Pressure;

        action filterFoamSolution {
            in item unfilteredFluid : FoamSolution;
            out item filteredFluid : FoamSolution;
        }

        requirement filterPressureDropRequirement {
            id = "FPS-FLT-001";
            text = "The suction filter shall not exceed 25 kPa pressure drop at rated flow.";
            require constraint {
                actualPressureDrop <= maximumPressureDrop;
            }
        }
    }

    part def DischargeCheckValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;

        attribute crackingPressure : Pressure = 15000 [SI::pascal];
        attribute reverseLeakageFlow : FlowRate;
        attribute open : ScalarValues::Boolean;

        state def CheckValveState {
            state Closed;
            state Open;
            transition initial then Closed;
            transition Closed_to_Open
                first Closed
                if inlet.inletPressure > crackingPressure
                then Open;
            transition Open_to_Closed
                first Open
                if inlet.inletPressure <= crackingPressure
                then Closed;
        }

        requirement noReverseFlowRequirement {
            id = "FPS-CV-001";
            text = "The discharge check valve shall limit reverse leakage to less than 0.5 liters per minute.";
            require constraint {
                reverseLeakageFlow < 0.5 [SI::litre / SI::minute];
            }
        }
    }

    part def PressureReliefValve {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port drain : DrainPort;

        attribute setPressure : Pressure = 800000 [SI::pascal];
        attribute reseatPressure : Pressure = 700000 [SI::pascal];
        attribute bypassFlow : FlowRate;
        attribute open : ScalarValues::Boolean;

        state def ReliefValveState {
            state Closed;
            state Relieving;
            transition initial then Closed;
            transition Closed_to_Relieving
                first Closed
                if inlet.inletPressure >= setPressure
                then Relieving;
            transition Relieving_to_Closed
                first Relieving
                if inlet.inletPressure <= reseatPressure
                then Closed;
        }

        requirement reliefPressureRequirement {
            id = "FPS-RV-001";
            text = "The relief valve shall open before subsystem discharge pressure exceeds 850 kPa.";
            require constraint {
                setPressure < 850000 [SI::pascal];
            }
        }
    }

    part def DischargeManifold {
        port inlet : FluidInletPort;
        port outlet : FluidOutletPort;
        port telemetryOutput : TelemetryPort;

        attribute manifoldVolume : Volume = 2.5 [SI::litre];
        attribute ratedPressure : Pressure = 1000000 [SI::pascal];
        attribute measuredPressure : Pressure;
        attribute measuredFlow : FlowRate;

        requirement manifoldPressureRating {
            id = "FPS-MAN-001";
            text = "The discharge manifold shall be rated above the maximum discharge pressure of the foam pump.";
            require constraint {
                ratedPressure >= 1000000 [SI::pascal];
            }
        }
    }

    part def MotorController {
        port powerInput : PowerPort;
        port commandInput : CommandPort;
        port telemetryOutput : TelemetryPort;

        attribute nominalVoltage : Voltage = 48 [SI::volt];
        attribute maximumCurrent : Current = 80 [SI::ampere];
        attribute outputPower : Power;
        attribute requestedSpeed : RotationalSpeed;
        attribute enabled : ScalarValues::Boolean;

        action regulatePumpSpeed {
            in requestedFlow : FlowRate;
            in measuredFlow : FlowRate;
            out commandedSpeed : RotationalSpeed;
        }

        requirement motorControllerPowerRequirement {
            id = "FPS-MC-001";
            text = "The motor controller shall provide sufficient electrical power to drive the foam pump at rated hydraulic output.";
            require constraint {
                outputPower >= 2200 [SI::watt];
            }
        }
    }

    part def SensorSet {
        port pressureTap : FluidInletPort;
        port flowTap : FluidOutletPort;
        port telemetryOutput : TelemetryPort;

        attribute pressureAccuracy : Pressure = 5000 [SI::pascal];
        attribute flowAccuracy : FlowRate = 2 [SI::litre / SI::minute];
        attribute temperatureAccuracy : Temperature = 1 [SI::degreeCelsius];
        attribute measuredPressure : Pressure;
        attribute measuredFlow : FlowRate;
        attribute measuredTemperature : Temperature;

        action sampleSensors {
            out signal : SensorSignal;
        }

        requirement sensorAccuracyRequirement {
            id = "FPS-SNS-001";
            text = "The sensor set shall measure discharge pressure within 5 kPa and flow within 2 liters per minute.";
            require constraint {
                pressureAccuracy <= 5000 [SI::pascal] and flowAccuracy <= 2 [SI::litre / SI::minute];
            }
        }
    }

    part def PumpController {
        port commandInput : CommandPort;
        port pumpCommandOutput : CommandPort;
        port telemetryInput : TelemetryPort;
        port telemetryOutput : TelemetryPort;

        attribute targetFlow : FlowRate = 120 [SI::litre / SI::minute];
        attribute targetPressure : Pressure = 650000 [SI::pascal];
        attribute lowLevelLimit : LiquidLevel = 0.15;
        attribute highPressureLimit : Pressure = 850000 [SI::pascal];
        attribute activeFault : FaultCode;

        action executeControlLoop {
            in operatorCommand : ControlSignal;
            in sensorFeedback : SensorSignal;
            out pumpCommand : ControlSignal;

            first validateCommand;
            then evaluateInterlocks;
            then calculateFlowDemand;
            then issuePumpCommand;

            action validateCommand {
                in command : ControlSignal = operatorCommand;
                out valid : ScalarValues::Boolean;
            }

            action evaluateInterlocks {
                in feedback : SensorSignal = sensorFeedback;
                out permissive : ScalarValues::Boolean;
                out fault : FaultCode;
            }

            action calculateFlowDemand {
                in desiredFlow : FlowRate = targetFlow;
                in actualFlow : FlowRate;
                out adjustedFlow : FlowRate;
            }

            action issuePumpCommand {
                in permissive : ScalarValues::Boolean;
                in adjustedFlow : FlowRate;
                out command : ControlSignal = pumpCommand;
            }
        }

        state def ControllerState {
            state Idle;
            state Armed;
            state Pumping;
            state Protecting;
            state FaultLatched;

            transition initial then Idle;

            transition Idle_to_Armed
                first Idle
                accept ControlSignal
                if command == "ARM"
                then Armed;

            transition Armed_to_Pumping
                first Armed
                accept ControlSignal
                if command == "START"
                then Pumping;

            transition Pumping_to_Protecting
                first Pumping
                if telemetryInput.telemetrySignal.measuredPressure > highPressureLimit
                then Protecting;

            transition Pumping_to_FaultLatched
                first Pumping
                if telemetryInput.telemetrySignal.measuredLevel < lowLevelLimit
                then FaultLatched;

            transition Protecting_to_Pumping
                first Protecting
                if telemetryInput.telemetrySignal.measuredPressure < targetPressure
                then Pumping;

            transition Pumping_to_Idle
                first Pumping
                accept ControlSignal
                if command == "STOP"
                then Idle;

            transition FaultLatched_to_Idle
                first FaultLatched
                accept ControlSignal
                if command == "RESET"
                then Idle;
        }

        requirement controllerInterlockRequirement {
            id = "FPS-CTL-001";
            text = "The controller shall stop the foam pump when reservoir level is below 15 percent or discharge pressure exceeds 850 kPa.";
            require constraint {
                telemetryInput.telemetrySignal.measuredLevel < lowLevelLimit or
                telemetryInput.telemetrySignal.measuredPressure > highPressureLimit implies
                activeFault != "NONE";
            }
        }
    }

    part def FoamPumpingSubsystem {
        port reservoirFillInlet : FluidInletPort;
        port subsystemOutlet : FluidOutletPort;
        port electricalInput : PowerPort;
        port operatorCommandInput : CommandPort;
        port healthTelemetryOutput : TelemetryPort;
        port maintenanceDrain : DrainPort;

        part reservoir : FoamReservoir;
        part suctionFilter : SuctionFilter;
        part foamPump : FoamPump;
        part checkValve : DischargeCheckValve;
        part reliefValve : PressureReliefValve;
        part manifold : DischargeManifold;
        part motorController : MotorController;
        part sensors : SensorSet;
        part controller : PumpController;

        attribute subsystemRatedFlow : FlowRate = 120 [SI::litre / SI::minute];
        attribute subsystemRatedPressure : Pressure = 650000 [SI::pascal];
        attribute maximumOperatingPressure : Pressure = 850000 [SI::pascal];
        attribute minimumOperatingTemperature : Temperature = 1 [SI::degreeCelsius];
        attribute maximumOperatingTemperature : Temperature = 55 [SI::degreeCelsius];
        attribute nominalFoamExpansionRatio : FoamExpansionRatio = 8.0;

        connect reservoirFillInlet to reservoir.outlet;
        connect reservoir.outlet to suctionFilter.inlet;
        connect suctionFilter.outlet to foamPump.inlet;
        connect foamPump.outlet to checkValve.inlet;
        connect checkValve.outlet to reliefValve.inlet;
        connect reliefValve.outlet to manifold.inlet;
        connect manifold.outlet to subsystemOutlet;
        connect reliefValve.drain to reservoir.drain;
        connect reservoir.drain to maintenanceDrain;

        connect electricalInput to motorController.powerInput;
        connect motorController.commandInput to controller.pumpCommandOutput;
        connect operatorCommandInput to controller.commandInput;
        connect motorController.telemetryOutput to controller.telemetryInput;
        connect controller.pumpCommandOutput to foamPump.commandInput;
        connect electricalInput to foamPump.powerInput;

        connect manifold.telemetryOutput to sensors.flowTap;
        connect sensors.telemetryOutput to controller.telemetryInput;
        connect controller.telemetryOutput to healthTelemetryOutput;
        connect foamPump.telemetryOutput to healthTelemetryOutput;
        connect reservoir.telemetryOutput to healthTelemetryOutput;

        action deliverFoam {
            in item sourceFoam : FoamSolution;
            in startCommand : ControlSignal;
            out item deliveredFoam : FoamSolution;
            out telemetry : SensorSignal;

            first fillReservoir;
            then armController;
            then primePump;
            then regulateFlow;
            then dischargeToOutlet;

            action fillReservoir {
                in item fillFluid : FoamSolution = sourceFoam;
                out storedVolume : Volume;
            }

            action armController {
                in command : ControlSignal = startCommand;
                out armed : ScalarValues::Boolean;
            }

            action primePump {
                in item reservoirFluid : FoamSolution;
                out suctionReady : ScalarValues::Boolean;
            }

            action regulateFlow {
                in targetFlow : FlowRate = subsystemRatedFlow;
                in targetPressure : Pressure = subsystemRatedPressure;
                out regulatedFlow : FlowRate;
                out regulatedPressure : Pressure;
            }

            action dischargeToOutlet {
                in item regulatedFluid : FoamSolution;
                out item outletFluid : FoamSolution = deliveredFoam;
            }
        }

        state def SubsystemOperatingState {
            state Empty;
            state Ready;
            state Priming;
            state Pumping;
            state PressureRelief;
            state LowLevelShutdown;
            state Faulted;
            state Draining;

            transition initial then Empty;

            transition Empty_to_Ready
                first Empty
                if reservoir.level >= reservoir.lowLevelThreshold
                then Ready;

            transition Ready_to_Priming
                first Ready
                accept ControlSignal
                if command == "START"
                then Priming;

            transition Priming_to_Pumping
                first Priming
                if foamPump.inlet.inletPressure >= foamPump.minimumSuctionPressure
                then Pumping;

            transition Pumping_to_PressureRelief
                first Pumping
                if manifold.measuredPressure >= reliefValve.setPressure
                then PressureRelief;

            transition PressureRelief_to_Pumping
                first PressureRelief
                if manifold.measuredPressure <= reliefValve.reseatPressure
                then Pumping;

            transition Pumping_to_LowLevelShutdown
                first Pumping
                if reservoir.level < reservoir.lowLevelThreshold
                then LowLevelShutdown;

            transition Priming_to_Faulted
                first Priming
                if foamPump.inlet.inletPressure < foamPump.minimumSuctionPressure
                then Faulted;

            transition Pumping_to_Faulted
                first Pumping
                if manifold.measuredPressure > maximumOperatingPressure
                then Faulted;

            transition LowLevelShutdown_to_Ready
                first LowLevelShutdown
                if reservoir.level >= reservoir.lowLevelThreshold
                then Ready;

            transition Ready_to_Draining
                first Ready
                accept ControlSignal
                if command == "DRAIN"
                then Draining;

            transition Draining_to_Empty
                first Draining
                if reservoir.level == 0.0
                then Empty;
        }

        requirement subsystemFlowRequirement {
            id = "FPS-SYS-001";
            text = "The pumping subsystem shall deliver foam solution at not less than 120 liters per minute at the subsystem outlet while commanded to pump.";
            require constraint {
                subsystemOutlet.outletFlow >= subsystemRatedFlow;
            }
        }

        requirement subsystemPressureRequirement {
            id = "FPS-SYS-002";
            text = "The pumping subsystem shall maintain outlet pressure of at least 650 kPa during rated foam delivery.";
            require constraint {
                subsystemOutlet.outletPressure >= subsystemRatedPressure;
            }
        }

        requirement overpressureProtectionRequirement {
            id = "FPS-SYS-003";
            text = "The pumping subsystem shall protect itself from overpressure above 850 kPa by opening the relief valve or stopping the pump.";
            require constraint {
                manifold.measuredPressure > maximumOperatingPressure implies
                reliefValve.open == true or foamPump.enabled == false;
            }
        }

        requirement lowLevelProtectionRequirement {
            id = "FPS-SYS-004";
            text = "The pumping subsystem shall stop pumping when reservoir level falls below 15 percent usable volume.";
            require constraint {
                reservoir.level < reservoir.lowLevelThreshold implies foamPump.enabled == false;
            }
        }

        requirement foamIntegrityRequirement {
            id = "FPS-SYS-005";
            text = "The subsystem shall preserve foam solution expansion ratio between 6 and 10 during pumping.";
            require constraint {
                subsystemOutlet.outgoingFoamSolution.expansionRatio >= 6.0 and
                subsystemOutlet.outgoingFoamSolution.expansionRatio <= 10.0;
            }
        }

        requirement operatingTemperatureRequirement {
            id = "FPS-SYS-006";
            text = "The subsystem shall operate with foam solution temperature from 1 degC to 55 degC.";
            require constraint {
                reservoir.solutionTemperature >= minimumOperatingTemperature and
                reservoir.solutionTemperature <= maximumOperatingTemperature;
            }
        }

        requirement telemetryRequirement {
            id = "FPS-SYS-007";
            text = "The subsystem shall report measured flow, pressure, temperature, reservoir level, and active fault status through the health telemetry port.";
            require constraint {
                healthTelemetryOutput.telemetrySignal.measuredFlow >= 0 [SI::litre / SI::minute] and
                healthTelemetryOutput.telemetrySignal.measuredPressure >= 0 [SI::pascal] and
                healthTelemetryOutput.telemetrySignal.measuredLevel >= 0.0;
            }
        }

        requirement electricalPowerRequirement {
            id = "FPS-SYS-008";
            text = "The subsystem shall operate from a 48 VDC electrical input and consume no more than 3.5 kW during rated pumping.";
            require constraint {
                electricalInput.suppliedPower.voltage == 48 [SI::volt] and
                electricalInput.suppliedPower.power <= 3500 [SI::watt];
            }
        }
    }

    satisfy FoamPumpingSubsystem::foamPump::pumpPressureCapability by FoamPumpingSubsystem::foamPump;
    satisfy FoamPumpingSubsystem::foamPump::pumpDryRunProtection by FoamPumpingSubsystem::controller;
    satisfy FoamPumpingSubsystem::reservoir::reservoirCapacityRequirement by FoamPumpingSubsystem::reservoir;
    satisfy FoamPumpingSubsystem::suctionFilter::filterPressureDropRequirement by FoamPumpingSubsystem::suctionFilter;
    satisfy FoamPumpingSubsystem::checkValve::noReverseFlowRequirement by FoamPumpingSubsystem::checkValve;
    satisfy FoamPumpingSubsystem::reliefValve::reliefPressureRequirement by FoamPumpingSubsystem::reliefValve;
    satisfy FoamPumpingSubsystem::manifold::manifoldPressureRating by FoamPumpingSubsystem::manifold;
    satisfy FoamPumpingSubsystem::motorController::motorControllerPowerRequirement by FoamPumpingSubsystem::motorController;
    satisfy FoamPumpingSubsystem::sensors::sensorAccuracyRequirement by FoamPumpingSubsystem::sensors;
    satisfy FoamPumpingSubsystem::controller::controllerInterlockRequirement by FoamPumpingSubsystem::controller;
    satisfy FoamPumpingSubsystem::subsystemFlowRequirement by FoamPumpingSubsystem;
    satisfy FoamPumpingSubsystem::subsystemPressureRequirement by FoamPumpingSubsystem;
    satisfy FoamPumpingSubsystem::overpressureProtectionRequirement by FoamPumpingSubsystem::reliefValve;
    satisfy FoamPumpingSubsystem::lowLevelProtectionRequirement by FoamPumpingSubsystem::controller;
    satisfy FoamPumpingSubsystem::foamIntegrityRequirement by FoamPumpingSubsystem::foamPump;
    satisfy FoamPumpingSubsystem::operatingTemperatureRequirement by FoamPumpingSubsystem::reservoir;
    satisfy FoamPumpingSubsystem::telemetryRequirement by FoamPumpingSubsystem::sensors;
    satisfy FoamPumpingSubsystem::electricalPowerRequirement by FoamPumpingSubsystem::motorController;
}