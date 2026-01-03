package 'LobePumpSubsystem' {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        item def Fluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : Real;
        }

        attribute def FlowRate :> ISQ::volumeFlowRate {
            attribute :>> num : Real;
        }

        attribute def Pressure :> ISQ::pressure {
            attribute :>> num : Real;
        }

        attribute def RotationalSpeed :> ISQ::angularVelocity {
            attribute :>> num : Real;
        }

        attribute def Torque :> ISQ::torque {
            attribute :>> num : Real;
        }

        attribute def Power :> ISQ::power {
            attribute :>> num : Real;
        }

        attribute def Volume :> ISQ::volume {
            attribute :>> num : Real;
        }

        port def FluidPort {
            attribute pressure : Pressure;
            inout item fluid : Fluid;
            attribute flowRate : FlowRate;
        }

        port def ElectricalPort {
            in attribute voltage : Real;
            in attribute current : Real;
        }

        port def MechanicalPort {
            attribute torque : Torque;
            attribute speed : RotationalSpeed;
        }

        port def ControlPort {
            in attribute commandedSpeed : RotationalSpeed;
            out attribute actualSpeed : RotationalSpeed;
            out attribute operatingStatus : OperatingStatus;
        }

        enum def OperatingStatus {
            enum stopped;
            enum starting;
            enum running;
            enum stopping;
            enum fault;
        }

        part def LobeRotor {
            attribute numberOfLobes : Integer;
            attribute diameter : Real;
            attribute length : Real;
            attribute angularPosition : Real;

            port shaftConnection : ~MechanicalPort;
        }

        part def LobePumpChamber {
            attribute chamberVolume : Real;
            attribute clearance : Real;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            part drivingRotor : LobeRotor {
                attribute :>> numberOfLobes = 2;
                attribute :>> diameter = 0.15;
                attribute :>> length = 0.20;
            }

            part drivenRotor : LobeRotor {
                attribute :>> numberOfLobes = 2;
                attribute :>> diameter = 0.15;
                attribute :>> length = 0.20;
            }

            assert constraint synchronizedRotation {
                doc /* The driven rotor must rotate synchronously with the driving rotor at 180 degrees phase offset */
                drivingRotor.angularPosition + 180.0 == drivenRotor.angularPosition
            }

            assert constraint minimumClearance {
                doc /* Maintain minimum clearance to prevent rotor contact */
                clearance >= 0.0001 and clearance <= 0.0005
            }
        }

        action def MotorControlBehavior {
            in commandSpeed : RotationalSpeed;
            out currentSpeed : RotationalSpeed;
            out currentStatus : OperatingStatus;

            first start;
            then merge checkCommand;

            then decide;
                if commandSpeed.num > 0.0 then startMotor;
                if commandSpeed.num == 0.0 then stopMotor;

            action startMotor {
                first assign currentStatus = OperatingStatus::starting;
                then rampUp;

                action rampUp {
                    first assign currentSpeed = commandSpeed;
                    then assign currentStatus = OperatingStatus::running;
                }
            }
            then checkCommand;

            action stopMotor {
                first assign currentStatus = OperatingStatus::stopping;
                then rampDown;

                action rampDown {
                    first assign currentSpeed.num = 0.0;
                    then assign currentStatus = OperatingStatus::stopped;
                }
            }
            then checkCommand;
        }

        part def ElectricMotor {
            attribute ratedPower : Power;
            attribute efficiency : Real;
            attribute currentSpeed : RotationalSpeed;

            port powerInput : ElectricalPort;
            port controlInput : ControlPort;
            port shaftOutput : MechanicalPort;

            perform action motorControl : MotorControlBehavior;
        }

        part def GearSet {
            attribute gearRatio : Real;
            attribute efficiency : Real;

            port inputShaft : ~MechanicalPort;
            port outputShaft : MechanicalPort;
        }

        action def LobePumpOperation {
            in inletPressure : Pressure;
            in rotorSpeed : RotationalSpeed;
            out outletPressure : Pressure;
            out deliveredFlowRate : FlowRate;

            first start;
            then captureFluid;

            action captureFluid {
                doc /* Fluid is captured between the lobes as they unmesh at the inlet */
            }
            then transferFluid;

            action transferFluid {
                doc /* Fluid is carried around the chamber periphery in the lobe pockets */
            }
            then dischargeFluid;

            action dischargeFluid {
                doc /* Fluid is discharged as the lobes mesh at the outlet */
                first assign deliveredFlowRate.num = rotorSpeed.num * 0.0025 * 60.0;
                then assign outletPressure.num = inletPressure.num + 500000.0;
            }
            then done;
        }

        state def LobePumpStates {
            entry; then idle;

            state idle {
                entry assign systemStatus = OperatingStatus::stopped;
            }
            accept StartCommand;
            then priming;

            state priming {
                entry assign systemStatus = OperatingStatus::starting;
                do action primePump {
                    doc /* Fill the pump chamber with fluid and remove air */
                }
            }
            then operating;

            state operating {
                entry assign systemStatus = OperatingStatus::running;

                state normalOperation;
                accept HighPressureDetected;
                then pressureRelief;

                state pressureRelief {
                    do action reduceSpeed {
                        doc /* Reduce pump speed to lower discharge pressure */
                    }
                }
                accept PressureNormalized;
                then normalOperation;
            }
            accept StopCommand;
            then shutdown;

            state shutdown {
                entry assign systemStatus = OperatingStatus::stopping;
                do action stopRotors {
                    doc /* Decelerate rotors to zero speed */
                }
            }
            then idle;

            accept FaultDetected;
            then fault;

            state fault {
                entry assign systemStatus = OperatingStatus::fault;
            }
            accept ResetCommand;
            then idle;

            attribute systemStatus : OperatingStatus;
        }

        part def LobePump {
            attribute maxFlowRate : FlowRate;
            attribute maxPressure : Pressure;
            attribute maxSpeed : RotationalSpeed;
            attribute displacement : Real;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port powerPort : ElectricalPort;
            port controlPort : ControlPort;

            part motor : ElectricMotor {
                attribute :>> ratedPower : Power;
                attribute :>> efficiency = 0.92;
            }

            part gearSet : GearSet {
                attribute :>> gearRatio = 1.0;
                attribute :>> efficiency = 0.98;
            }

            part pumpChamber : LobePumpChamber {
                attribute :>> chamberVolume = 0.0025;
                attribute :>> clearance = 0.0002;
            }

            part driveshaft {
                attribute diameter : Real = 0.04;
                attribute length : Real = 0.30;
            }

            bind powerPort = motor.powerInput;
            bind controlPort = motor.controlInput;
            bind inletPort = pumpChamber.inletPort;
            bind outletPort = pumpChamber.outletPort;

            connect motor.shaftOutput to gearSet.inputShaft;
            connect gearSet.outputShaft to driveshaft;
            connect driveshaft to pumpChamber.drivingRotor.shaftConnection;

            perform action pumpOperation : LobePumpOperation;

            state pumpStateMachine : LobePumpStates;
        }

        part def FluidReservoir {
            attribute capacity : Volume;
            attribute currentLevel : Volume;

            port outletPort : FluidPort;

            item storedFluid : Fluid;
        }

        part def FluidReceiver {
            attribute capacity : Volume;
            attribute currentLevel : Volume;

            port inletPort : ~FluidPort;

            item receivedFluid : Fluid;
        }

        part def PressureSensor {
            port sensingPort : ~FluidPort;
            out attribute measuredPressure : Pressure;
        }

        part def FlowMeter {
            port sensingPort : ~FluidPort;
            out attribute measuredFlowRate : FlowRate;
        }

        part def ReliefValve {
            attribute setPoint : Pressure;
            attribute crackingPressure : Pressure;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            state valveState {
                entry; then closed;

                state closed;
                accept when crackingPressure.num > 0.0;
                then opening;

                state opening;
                then open;

                state open;
                accept when crackingPressure.num <= 0.0;
                then closing;

                state closing;
                then closed;
            }
        }

        action def SystemOperation {
            first start;
            then initializeSystem;

            action initializeSystem {
                doc /* Verify all connections and prepare for operation */
            }
            then startPumping;

            action startPumping {
                doc /* Begin pumping operation */
            }
            then monitorOperation;

            action monitorOperation {
                doc /* Continuously monitor pressure, flow, and system status */
            }
            then decide;
                if true then stopPumping;

            action stopPumping {
                doc /* Shutdown pumping operation */
            }
            then done;
        }

        part def PumpingSubsystem {
            part sourceReservoir : FluidReservoir;
            part pump : LobePump;
            part destinationReceiver : FluidReceiver;
            part inletPressureSensor : PressureSensor;
            part outletPressureSensor : PressureSensor;
            part flowMeter : FlowMeter;
            part reliefValve : ReliefValve;

            flow of fluid : Fluid
                from sourceReservoir.outletPort.fluid
                to inletPressureSensor.sensingPort.fluid;

            flow of fluid : Fluid
                from inletPressureSensor.sensingPort.fluid
                to pump.inletPort.fluid;

            flow of fluid : Fluid
                from pump.outletPort.fluid
                to outletPressureSensor.sensingPort.fluid;

            flow of fluid : Fluid
                from outletPressureSensor.sensingPort.fluid
                to flowMeter.sensingPort.fluid;

            flow of fluid : Fluid
                from flowMeter.sensingPort.fluid
                to reliefValve.inletPort.fluid;

            flow of fluid : Fluid
                from reliefValve.outletPort.fluid
                to destinationReceiver.inletPort.fluid;

            perform action systemOperation : SystemOperation;
        }

        requirement def PumpPerformanceRequirement {
            doc /* The lobe pump shall deliver the specified flow rate at the specified pressure */

            subject pump : LobePump;

            require constraint flowRateRequirement {
                pump.maxFlowRate.num >= 150.0
            }

            require constraint pressureRequirement {
                pump.maxPressure.num >= 1000000.0
            }

            require constraint efficiencyRequirement {
                pump.motor.efficiency >= 0.90
            }
        }

        requirement def SynchronizationRequirement {
            doc /* The lobe rotors shall maintain precise synchronization to prevent contact */

            subject chamber : LobePumpChamber;

            require constraint timingRequirement {
                chamber.drivingRotor.angularPosition + 180.0 == chamber.drivenRotor.angularPosition
            }

            require constraint clearanceRequirement {
                chamber.clearance >= 0.0001 and chamber.clearance <= 0.0005
            }
        }

        requirement def SafetyRequirement {
            doc /* The pumping system shall include overpressure protection */

            subject system : PumpingSubsystem;

            require constraint reliefValveRequirement {
                system.reliefValve.setPoint.num <= system.pump.maxPressure.num * 1.1
            }
        }
    }

    package Usages {
        part pumpingSubsystem : Definitions::PumpingSubsystem {
            part :>> sourceReservoir {
                attribute :>> capacity : Volume;
                attribute :>> currentLevel : Volume;

                item :>> storedFluid {
                    attribute :>> density = 1000.0;
                    attribute :>> viscosity = 0.001;
                    attribute :>> temperature = 20.0;
                }
            }

            part :>> pump {
                attribute :>> maxFlowRate : FlowRate;
                attribute :>> maxPressure : Pressure;
                attribute :>> maxSpeed : RotationalSpeed;
                attribute :>> displacement = 0.0025;
            }

            part :>> destinationReceiver {
                attribute :>> capacity : Volume;
                attribute :>> currentLevel : Volume;
            }

            part :>> reliefValve {
                attribute :>> setPoint : Pressure;
                attribute :>> crackingPressure : Pressure;
            }

            satisfy performanceReq : Definitions::PumpPerformanceRequirement {
                subject pump = pumpingSubsystem.pump;
            }

            satisfy syncReq : Definitions::SynchronizationRequirement {
                subject chamber = pumpingSubsystem.pump.pumpChamber;
            }

            satisfy safetyReq : Definitions::SafetyRequirement {
                subject system = pumpingSubsystem;
            }
        }
    }
}
