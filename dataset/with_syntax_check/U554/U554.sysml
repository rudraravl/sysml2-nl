package RotaryVanePumpingSubsystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;

    package Definitions {
        attribute def PressureValue {
            attribute magnitude : Real;
            attribute unit : PressureUnit;
        }

        attribute def FlowRateValue {
            attribute magnitude : Real;
            attribute unit : VolumeFlowRateUnit;
        }

        attribute def RotationalSpeedValue {
            attribute magnitude : Real;
            attribute unit : AngularVelocityUnit;
        }

        attribute def TorqueValue {
            attribute magnitude : Real;
            attribute unit : TorqueUnit;
        }

        attribute def PowerValue {
            attribute magnitude : Real;
            attribute unit : PowerUnit;
        }

        attribute def TemperatureValue {
            attribute magnitude : Real;
            attribute unit : TemperatureUnit;
        }

        attribute def VoltageValue {
            attribute magnitude : Real;
            attribute unit : ElectricPotentialUnit;
        }

        attribute def CurrentValue {
            attribute magnitude : Real;
            attribute unit : ElectricCurrentUnit;
        }

        item def HydraulicFluid {
            attribute density : Real;
            attribute viscosity : Real;
            attribute temperature : TemperatureValue;
            attribute volume : VolumeValue;
        }

        port def FluidPort {
            attribute pressure : PressureValue;
            attribute flowRate : FlowRateValue;
            attribute temperature : TemperatureValue;
            in item fluidIn : HydraulicFluid;
            out item fluidOut : HydraulicFluid;
        }

        port def MechanicalShaftPort {
            attribute speed : RotationalSpeedValue;
            attribute torque : TorqueValue;
            attribute power : PowerValue;
        }

        port def ElectricalPort {
            attribute voltage : VoltageValue;
            attribute current : CurrentValue;
            attribute power : PowerValue;
        }

        part def RotaryVanePump {
            doc /*
             * Rotary vane pump with eccentric rotor and sliding vanes
             * that create expanding and contracting chambers to move fluid.
             */

            attribute numberOfVanes : Integer = 8;
            attribute eccentricity : LengthValue;
            attribute rotorDiameter : LengthValue;
            attribute housingDiameter : LengthValue;
            attribute vaneLength : LengthValue;
            attribute vaneThickness : LengthValue;
            attribute displacementPerRevolution : VolumeValue;
            attribute volumetricEfficiency : Real;
            attribute mechanicalEfficiency : Real;
            attribute maxPressure : PressureValue;
            attribute maxSpeed : RotationalSpeedValue;
            attribute minInletPressure : PressureValue;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port driveShaft : ~MechanicalShaftPort;

            part rotor {
                attribute diameter : LengthValue = rotorDiameter;
                attribute numberOfSlots : Integer = numberOfVanes;
            }

            part housing {
                attribute innerDiameter : LengthValue = housingDiameter;
                attribute eccentricOffset : LengthValue = eccentricity;
            }

            part vanes[numberOfVanes] {
                attribute length : LengthValue = vaneLength;
                attribute thickness : LengthValue = vaneThickness;
                attribute material : String = "Carbon composite";
            }

            part inletChamber {
                port fluidConnection : ~FluidPort;
            }

            part outletChamber {
                port fluidConnection : FluidPort;
            }

            part pumpingChambers[numberOfVanes] {
                attribute currentVolume : VolumeValue;
                attribute isExpanding : Boolean;
            }

            binding inletPort = inletChamber.fluidConnection;
            binding outletPort = outletChamber.fluidConnection;

            perform action pumpingOperation : PumpFluid {
                in shaftSpeed = driveShaft.speed;
                in shaftTorque = driveShaft.torque;
                in inletPressure = inletPort.pressure;
                in inletFluid = inletPort.fluidIn;
                out outletPressure = outletPort.pressure;
                out outletFlow = outletPort.flowRate;
                out outletFluid = outletPort.fluidOut;
            }

            perform pumpStateMachine : PumpOperatingStates;

            assert constraint flowCalculation {
                outletPort.flowRate.magnitude == 
                    driveShaft.speed.magnitude * displacementPerRevolution.magnitude * volumetricEfficiency
            }

            assert constraint pressureDifferential {
                outletPort.pressure.magnitude - inletPort.pressure.magnitude <= maxPressure.magnitude
            }
        }

        part def ElectricMotor {
            doc /*
             * Three-phase electric motor driving the pump shaft.
             */

            attribute ratedPower : PowerValue;
            attribute ratedSpeed : RotationalSpeedValue;
            attribute ratedTorque : TorqueValue;
            attribute ratedVoltage : VoltageValue;
            attribute ratedCurrent : CurrentValue;
            attribute motorEfficiency : Real;
            attribute powerFactor : Real;

            port powerInput : ~ElectricalPort;
            port outputShaft : MechanicalShaftPort;

            perform action driveOperation : DriveMotor {
                in voltage = powerInput.voltage;
                in current = powerInput.current;
                out shaftSpeed = outputShaft.speed;
                out shaftTorque = outputShaft.torque;
            }

            assert constraint powerConversion {
                outputShaft.power.magnitude == 
                    powerInput.voltage.magnitude * powerInput.current.magnitude * powerFactor * motorEfficiency
            }
        }

        part def FluidReservoir {
            doc /*
             * Hydraulic fluid storage tank with level monitoring.
             */

            attribute capacity : VolumeValue;
            attribute currentLevel : VolumeValue;
            attribute minLevel : VolumeValue;
            attribute maxLevel : VolumeValue;
            attribute ambientPressure : PressureValue;

            port outletPort : FluidPort;
            port returnPort : ~FluidPort;

            item storedFluid : HydraulicFluid {
                attribute :>> volume = currentLevel;
            }

            assert constraint levelLimits {
                currentLevel.magnitude >= minLevel.magnitude and currentLevel.magnitude <= maxLevel.magnitude
            }
        }

        part def PressureReliefValve {
            doc /*
             * Spring-loaded valve to protect system from overpressure.
             */

            attribute crackingPressure : PressureValue;
            attribute fullFlowPressure : PressureValue;
            attribute flowCapacity : FlowRateValue;
            attribute springStiffness : Real;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port reliefPort : FluidPort;

            perform action reliefControl : ReliefValveControl {
                in inletPressure = inletPort.pressure;
                in setCrackingPressure = crackingPressure;
                out valvePosition : Real;
                out reliefFlow = reliefPort.flowRate;
            }
        }

        part def FluidFilter {
            doc /*
             * Hydraulic filter to remove contaminants from fluid.
             */

            attribute filtrationRating : LengthValue;
            attribute maxDifferentialPressure : PressureValue;
            attribute flowCapacity : FlowRateValue;
            attribute bypassValveSetting : PressureValue;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;

            part filterElement {
                attribute condition : String;
                attribute replacementRequired : Boolean;
                attribute currentDifferentialPressure : PressureValue;
            }

            assert constraint filterBypass {
                filterElement.currentDifferentialPressure.magnitude > bypassValveSetting.magnitude 
                    implies filterElement.replacementRequired == true
            }
        }

        part def PressureSensor {
            doc /*
             * Pressure transducer for monitoring system pressure.
             */

            attribute range : PressureValue;
            attribute accuracy : Real;
            attribute responseTime : TimeValue;

            port sensingPort : ~FluidPort;
            port signalOutput;

            attribute measuredPressure : PressureValue;
        }

        part def FlowMeter {
            doc /*
             * Turbine flow meter for measuring volumetric flow rate.
             */

            attribute range : FlowRateValue;
            attribute accuracy : Real;
            attribute kFactor : Real;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
            port signalOutput;

            attribute measuredFlow : FlowRateValue;
        }

        part def TemperatureSensor {
            doc /*
             * Thermocouple for monitoring fluid temperature.
             */

            attribute range : TemperatureValue;
            attribute accuracy : Real;

            port sensingPort : ~FluidPort;
            port signalOutput;

            attribute measuredTemperature : TemperatureValue;
        }

        part def CheckValve {
            doc /*
             * One-way valve to prevent backflow.
             */

            attribute crackingPressure : PressureValue;
            attribute flowCapacity : FlowRateValue;

            port inletPort : ~FluidPort;
            port outletPort : FluidPort;
        }

        action def PumpFluid {
            doc /*
             * Action representing the pumping cycle of the rotary vane pump.
             */

            in shaftSpeed : RotationalSpeedValue;
            in shaftTorque : TorqueValue;
            in inletPressure : PressureValue;
            in inletFluid : HydraulicFluid;
            out outletPressure : PressureValue;
            out outletFlow : FlowRateValue;
            out outletFluid : HydraulicFluid;

            action calculateDisplacement {
                doc /* Calculate volumetric displacement based on shaft speed and geometry */
            }

            action drawFluid {
                doc /* Draw fluid into expanding chambers on suction side */
            }

            action sealChambers {
                doc /* Seal chambers as vanes pass transition region */
            }

            action compressFluid {
                doc /* Compress fluid in contracting chambers */
            }

            action dischargeFluid {
                doc /* Discharge pressurized fluid from outlet */
            }

            first start;
            then calculateDisplacement;
            then drawFluid;
            then sealChambers;
            then compressFluid;
            then dischargeFluid;
            then done;
        }

        action def DriveMotor {
            doc /*
             * Action representing motor operation converting electrical to mechanical power.
             */

            in voltage : VoltageValue;
            in current : CurrentValue;
            out shaftSpeed : RotationalSpeedValue;
            out shaftTorque : TorqueValue;

            action energizeWindings;
            action generateRotatingField;
            action produceRotation;

            first start;
            then energizeWindings;
            then generateRotatingField;
            then produceRotation;
            then done;
        }

        action def ReliefValveControl {
            doc /*
             * Action controlling pressure relief valve operation.
             */

            in inletPressure : PressureValue;
            in setCrackingPressure : PressureValue;
            out valvePosition : Real;
            out reliefFlow : FlowRateValue;

            first start;
            then merge continuousMonitoring;
            then action monitorPressure {
                out currentPressure : PressureValue = inletPressure;
            }
            then decide;
                if monitorPressure.currentPressure.magnitude >= setCrackingPressure.magnitude then openValve;
                if monitorPressure.currentPressure.magnitude < setCrackingPressure.magnitude then closeValve;

            action openValve {
                out position : Real = (monitorPressure.currentPressure.magnitude - setCrackingPressure.magnitude) / 
                                       (setCrackingPressure.magnitude * 0.1);
            }
            then continuousMonitoring;

            action closeValve {
                out position : Real = 0.0;
            }
            then continuousMonitoring;
        }

        state def PumpOperatingStates {
            doc /*
             * State machine representing pump operational modes.
             */

            entry; then idle;

            state idle {
                doc /* Pump is stopped, no rotation */
            }

            state priming {
                doc /* Pump is filling with fluid, removing air */
            }

            state running {
                doc /* Pump is operating normally */

                state normalOperation {
                    doc /* Standard operating conditions */
                }

                state highPressure {
                    doc /* Operating at elevated discharge pressure */
                }

                state lowFlow {
                    doc /* Reduced flow due to low inlet pressure or cavitation */
                }

                state overTemperature {
                    doc /* Fluid temperature exceeds normal range */
                }

                transition normalToHighPressure
                    first normalOperation
                    accept pressureHigh
                    then highPressure;

                transition highPressureToNormal
                    first highPressure
                    accept pressureNormal
                    then normalOperation;

                transition normalToLowFlow
                    first normalOperation
                    accept flowLow
                    then lowFlow;

                transition lowFlowToNormal
                    first lowFlow
                    accept flowRestored
                    then normalOperation;

                transition normalToOverTemp
                    first normalOperation
                    accept temperatureHigh
                    then overTemperature;
            }

            state stopping {
                doc /* Pump is decelerating to stop */
            }

            state fault {
                doc /* Pump has encountered a fault condition */

                state cavitation {
                    doc /* Insufficient inlet pressure causing vapor formation */
                }

                state overpressure {
                    doc /* Discharge pressure exceeds maximum rating */
                }

                state mechanicalFailure {
                    doc /* Bearing failure, vane damage, or seal failure */
                }

                state motorOverload {
                    doc /* Motor current exceeds rated value */
                }
            }

            transition idleToStarting
                first idle
                accept startCommand
                then priming;

            transition primingToRunning
                first priming
                accept primingComplete
                then running;

            transition runningToStopping
                first running
                accept stopCommand
                then stopping;

            transition stoppingToIdle
                first stopping
                accept stopped
                then idle;

            transition toFault
                accept faultDetected
                then fault;

            transition faultToIdle
                first fault
                accept faultCleared
                then idle;

            accept startCommand;
            accept stopCommand;
            accept primingComplete;
            accept stopped;
            accept pressureHigh;
            accept pressureNormal;
            accept flowLow;
            accept flowRestored;
            accept temperatureHigh;
            accept faultDetected;
            accept faultCleared;
        }
    }

    package Usages {
        import Definitions::*;

        part pumpingSubsystem {
            doc /*
             * Complete rotary vane pumping subsystem with motor drive,
             * filtration, pressure relief, instrumentation, and control.
             */

            part reservoir : FluidReservoir {
                attribute :>> capacity {
                    attribute :>> magnitude = 100.0;
                }
                attribute :>> currentLevel {
                    attribute :>> magnitude = 75.0;
                }
                attribute :>> minLevel {
                    attribute :>> magnitude = 20.0;
                }
                attribute :>> maxLevel {
                    attribute :>> magnitude = 95.0;
                }
                attribute :>> ambientPressure {
                    attribute :>> magnitude = 1.0;
                }
            }

            flow from reservoir.outletPort.fluidOut to inletCheckValve.inletPort.fluidIn;

            part inletCheckValve : CheckValve {
                attribute :>> crackingPressure {
                    attribute :>> magnitude = 0.2;
                }
                attribute :>> flowCapacity {
                    attribute :>> magnitude = 80.0;
                }
            }

            flow from inletCheckValve.outletPort.fluidOut to inletFilter.inletPort.fluidIn;

            part inletFilter : FluidFilter {
                attribute :>> filtrationRating {
                    attribute :>> magnitude = 25.0;
                }
                attribute :>> maxDifferentialPressure {
                    attribute :>> magnitude = 3.5;
                }
                attribute :>> flowCapacity {
                    attribute :>> magnitude = 80.0;
                }
                attribute :>> bypassValveSetting {
                    attribute :>> magnitude = 3.0;
                }
            }

            flow from inletFilter.outletPort.fluidOut to pump.inletPort.fluidIn;

            part inletPressureSensor : PressureSensor {
                attribute :>> range {
                    attribute :>> magnitude = 5.0;
                }
                attribute :>> accuracy = 0.5;
                attribute :>> responseTime {
                    attribute :>> magnitude = 10.0;
                }
            }

            connect inletPressureSensor.sensingPort to pump.inletPort;

            part inletTempSensor : TemperatureSensor {
                attribute :>> range {
                    attribute :>> magnitude = 100.0;
                }
                attribute :>> accuracy = 1.0;
            }

            connect inletTempSensor.sensingPort to pump.inletPort;

            part pump : RotaryVanePump {
                attribute :>> numberOfVanes = 8;
                attribute :>> eccentricity {
                    attribute :>> magnitude = 6.5;
                }
                attribute :>> rotorDiameter {
                    attribute :>> magnitude = 85.0;
                }
                attribute :>> housingDiameter {
                    attribute :>> magnitude = 98.0;
                }
                attribute :>> vaneLength {
                    attribute :>> magnitude = 28.0;
                }
                attribute :>> vaneThickness {
                    attribute :>> magnitude = 3.5;
                }
                attribute :>> displacementPerRevolution {
                    attribute :>> magnitude = 0.145;
                }
                attribute :>> volumetricEfficiency = 0.92;
                attribute :>> mechanicalEfficiency = 0.88;
                attribute :>> maxPressure {
                    attribute :>> magnitude = 12.0;
                }
                attribute :>> maxSpeed {
                    attribute :>> magnitude = 1800.0;
                }
                attribute :>> minInletPressure {
                    attribute :>> magnitude = 0.8;
                }
            }

            part motor : ElectricMotor {
                attribute :>> ratedPower {
                    attribute :>> magnitude = 3.0;
                }
                attribute :>> ratedSpeed {
                    attribute :>> magnitude = 1450.0;
                }
                attribute :>> ratedTorque {
                    attribute :>> magnitude = 19.8;
                }
                attribute :>> ratedVoltage {
                    attribute :>> magnitude = 400.0;
                }
                attribute :>> ratedCurrent {
                    attribute :>> magnitude = 6.5;
                }
                attribute :>> motorEfficiency = 0.91;
                attribute :>> powerFactor = 0.85;
            }

            connect motor.outputShaft to pump.driveShaft;

            flow from pump.outletPort.fluidOut to outletFilter.inletPort.fluidIn;

            part outletFilter : FluidFilter {
                attribute :>> filtrationRating {
                    attribute :>> magnitude = 10.0;
                }
                attribute :>> maxDifferentialPressure {
                    attribute :>> magnitude = 3.5;
                }
                attribute :>> flowCapacity {
                    attribute :>> magnitude = 80.0;
                }
                attribute :>> bypassValveSetting {
                    attribute :>> magnitude = 3.0;
                }
            }

            flow from outletFilter.outletPort.fluidOut to reliefValve.inletPort.fluidIn;

            part reliefValve : PressureReliefValve {
                attribute :>> crackingPressure {
                    attribute :>> magnitude = 10.0;
                }
                attribute :>> fullFlowPressure {
                    attribute :>> magnitude = 11.0;
                }
                attribute :>> flowCapacity {
                    attribute :>> magnitude = 80.0;
                }
                attribute :>> springStiffness = 5000.0;
            }

            flow from reliefValve.reliefPort.fluidOut to reservoir.returnPort.fluidIn;

            part dischargePressureSensor : PressureSensor {
                attribute :>> range {
                    attribute :>> magnitude = 15.0;
                }
                attribute :>> accuracy = 0.5;
                attribute :>> responseTime {
                    attribute :>> magnitude = 10.0;
                }
            }

            connect dischargePressureSensor.sensingPort to reliefValve.outletPort;

            part dischargeFlowMeter : FlowMeter {
                attribute :>> range {
                    attribute :>> magnitude = 120.0;
                }
                attribute :>> accuracy = 1.0;
                attribute :>> kFactor = 450.0;
            }

            flow from reliefValve.outletPort.fluidOut to dischargeFlowMeter.inletPort.fluidIn;

            part dischargeTempSensor : TemperatureSensor {
                attribute :>> range {
                    attribute :>> magnitude = 100.0;
                }
                attribute :>> accuracy = 1.0;
            }

            connect dischargeTempSensor.sensingPort to dischargeFlowMeter.outletPort;

            port systemOutlet : FluidPort;

            binding dischargeFlowMeter.outletPort = systemOutlet;

            item hydraulicFluid : HydraulicFluid {
                attribute :>> density = 870.0;
                attribute :>> viscosity = 46.0;
                attribute :>> temperature {
                    attribute :>> magnitude = 40.0;
                }
                attribute :>> volume {
                    attribute :>> magnitude = 75.0;
                }
            }
        }
    }

    package Requirements {
        import Definitions::*;

        requirement pumpFlowRateReq {
            doc /* The pump shall deliver minimum flow rate at specified operating conditions */
            subject pump : RotaryVanePump;
            require constraint {
                pump.outletPort.flowRate.magnitude >= 50.0 and
                pump.driveShaft.speed.magnitude >= 1400.0
            }
        }

        requirement pumpPressureReq {
            doc /* The pump shall generate minimum discharge pressure */
            subject pump : RotaryVanePump;
            require constraint {
                pump.outletPort.pressure.magnitude >= 8.0 and
                pump.outletPort.pressure.magnitude <= pump.maxPressure.magnitude
            }
        }

        requirement pumpEfficiencyReq {
            doc /* The pump shall maintain minimum volumetric and mechanical efficiency */
            subject pump : RotaryVanePump;
            require constraint {
                pump.volumetricEfficiency >= 0.85 and
                pump.mechanicalEfficiency >= 0.82
            }
        }

        requirement pressureReliefReq {
            doc /* Pressure relief valve shall protect system from overpressure */
            subject valve : PressureReliefValve;
            require constraint {
                valve.crackingPressure.magnitude <= 10.0 and
                valve.fullFlowPressure.magnitude <= 11.0 and
                valve.flowCapacity.magnitude >= 80.0
            }
        }

        requirement filtrationReq {
            doc /* Filters shall maintain fluid cleanliness to ISO 4406 standard */
            subject inletFilter : FluidFilter;
            subject outletFilter : FluidFilter;
            require constraint {
                inletFilter.filtrationRating.magnitude <= 25.0 and
                outletFilter.filtrationRating.magnitude <= 10.0
            }
        }

        requirement motorPowerReq {
            doc /* Motor shall provide adequate power for pump operation at maximum conditions */
            subject motor : ElectricMotor;
            subject pump : RotaryVanePump;
            require constraint {
                motor.ratedPower.magnitude >= 2.5 and
                motor.motorEfficiency >= 0.88
            }
        }

        requirement reservoirCapacityReq {
            doc /* Reservoir shall maintain adequate fluid volume for system operation */
            subject reservoir : FluidReservoir;
            require constraint {
                reservoir.currentLevel.magnitude >= reservoir.minLevel.magnitude and
                reservoir.currentLevel.magnitude <= reservoir.maxLevel.magnitude and
                reservoir.capacity.magnitude >= 100.0
            }
        }

        requirement inletPressureReq {
            doc /* Pump inlet pressure shall remain above minimum to prevent cavitation */
            subject pump : RotaryVanePump;
            require constraint {
                pump.inletPort.pressure.magnitude >= pump.minInletPressure.magnitude
            }
        }

        requirement temperatureReq {
            doc /* Hydraulic fluid temperature shall remain within operating range */
            subject fluid : HydraulicFluid;
            require constraint {
                fluid.temperature.magnitude >= 20.0 and
                fluid.temperature.magnitude <= 80.0
            }
        }

        requirement systemFlowReq {
            doc /* System shall deliver minimum flow rate to outlet */
            subject subsystem : Usages::pumpingSubsystem;
            require constraint {
                subsystem.systemOutlet.flowRate.magnitude >= 45.0
            }
        }
    }
}
