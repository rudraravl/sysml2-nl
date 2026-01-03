package HondaPumpSystem {
    private import ScalarValues::*;
    private import ISQ::*;
    private import SI::*;
    private import Time::*;

    attribute def FlowRateValue :> VolumeFlowRateValue;
    attribute def PressureValue :> ISQ::PressureValue;
    attribute def RotationalSpeedValue :> FrequencyValue;
    attribute def TemperatureValue :> ThermodynamicTemperatureValue;
    attribute def FuelLevelValue :> VolumeValue;

    enum def PumpOperatingMode {
        off;
        priming;
        running;
        stopping;
        fault;
    }

    enum def FuelType {
        gasoline;
        diesel;
    }

    port def FluidPort {
        attribute pressure : PressureValue;
        attribute flowRate : FlowRateValue;
        attribute temperature : TemperatureValue;
    }

    port def MechanicalPort {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
        attribute power : PowerValue;
    }

    item def Water {
        attribute density : MassDensityValue = 1000 [kg/m^3];
        attribute viscosity : Real = 0.001;
        attribute temperature : TemperatureValue;
    }

    part def GasolineEngine {
        attribute displacement : VolumeValue = 163 [cm^3];
        attribute maxPower : PowerValue = 4.0 [kW];
        attribute ratedSpeed : RotationalSpeedValue = 3600 [1/min];
        attribute currentSpeed : RotationalSpeedValue;
        attribute isRunning : Boolean = false;
        attribute fuelType : FuelType = FuelType::gasoline;

        port shaft : MechanicalPort {
            attribute :>> torque;
            attribute :>> speed;
            attribute :>> power;
        }

        part fuelTank {
            attribute capacity : VolumeValue = 3.1 [L];
            attribute currentLevel : FuelLevelValue;
            attribute consumptionRate : FlowRateValue = 1.5 [L/h];
        }

        part ignitionSystem {
            attribute sparkTiming : Real;
            attribute voltage : Real = 12;
        }

        part coolingSystem {
            attribute coolantTemperature : TemperatureValue;
            attribute airFlow : FlowRateValue;
        }

        action def StartEngine {
            in fuelAvailable : Boolean;
            out running : Boolean;
        }

        action def StopEngine {
            out running : Boolean = false;
        }

        action def AdjustThrottle {
            in targetSpeed : RotationalSpeedValue;
            out actualSpeed : RotationalSpeedValue;
        }
    }

    part def CentrifugalPumpHead {
        attribute impellerDiameter : LengthValue = 120 [mm];
        attribute bladeCount : Integer = 6;
        attribute efficiency : Real = 0.65;
        attribute maxHead : LengthValue = 30 [m];
        attribute ratedFlowRate : FlowRateValue = 600 [L/min];

        port inlet : FluidPort;
        port outlet : FluidPort;
        port driveShaft : MechanicalPort;

        part impeller {
            attribute material : String = "cast_iron";
            attribute rotationSpeed : RotationalSpeedValue;
        }

        part volute {
            attribute volume : VolumeValue = 0.8 [L];
            attribute maxPressure : PressureValue = 400000 [Pa];
        }

        part shaft {
            attribute diameter : LengthValue = 20 [mm];
            attribute length : LengthValue = 150 [mm];
            attribute material : String = "stainless_steel";
        }

        part bearings {
            attribute type : String = "ball_bearing";
            attribute lubrication : String = "grease";
            attribute count : Integer = 2;
        }

        part mechanicalSeal {
            attribute sealType : String = "carbon_ceramic";
            attribute maxPressure : PressureValue = 500000 [Pa];
            attribute maxTemperature : TemperatureValue = 363 [K];
        }

        action def PumpFluid {
            in inputPower : PowerValue;
            in inletPressure : PressureValue;
            out outletPressure : PressureValue;
            out deliveredFlow : FlowRateValue;
        }
    }

    part def PrimingSystem {
        attribute chamberVolume : VolumeValue = 0.6 [L];
        attribute isPrimed : Boolean = false;

        part primingChamber {
            attribute volume : VolumeValue = 0.6 [L];
        }

        part checkValve {
            attribute crackingPressure : PressureValue = 5000 [Pa];
        }

        action def PrimePump {
            in fluid : Water;
            out primed : Boolean;
        }
    }

    part def ControlSystem {
        attribute throttlePosition : Real = 0.0;
        attribute targetFlowRate : FlowRateValue;

        part throttleActuator {
            attribute position : Real;
            attribute maxPosition : Real = 1.0;
        }

        part pressureGauge {
            attribute reading : PressureValue;
            attribute accuracy : Real = 0.02;
        }

        part flowMeter {
            attribute reading : FlowRateValue;
            attribute accuracy : Real = 0.015;
        }

        action def MonitorPerformance {
            in currentPressure : PressureValue;
            in currentFlow : FlowRateValue;
            out adjustmentNeeded : Boolean;
        }

        action def AdjustThrottle {
            in targetFlow : FlowRateValue;
            in currentFlow : FlowRateValue;
            out throttleChange : Real;
        }
    }

    part def StructuralFrame {
        attribute material : String = "steel";
        attribute frameMass : MassValue = 8.5 [kg];
        attribute dimensions : String = "500x400x350mm";

        part mountingPlate {
            attribute thickness : LengthValue = 5 [mm];
        }

        part vibrationIsolators {
            attribute count : Integer = 4;
            attribute stiffness : Real;
        }

        part handleAssembly {
            attribute height : LengthValue = 900 [mm];
        }
    }

    part def HondaPump {
        attribute totalMass : MassValue;
        attribute operatingMode : PumpOperatingMode = PumpOperatingMode::off;
        attribute ratedFlowRate : FlowRateValue = 600 [L/min];
        attribute ratedPressure : PressureValue = 300000 [Pa];
        attribute maxHead : LengthValue = 30 [m];
        attribute overallEfficiency : Real;

        port suctionPort : FluidPort;
        port dischargePort : FluidPort;

        part engine : GasolineEngine {
            attribute :>> maxPower = 4.0 [kW];
            attribute :>> displacement = 163 [cm^3];
            attribute :>> ratedSpeed = 3600 [1/min];
        }

        part pumpHead : CentrifugalPumpHead {
            attribute :>> ratedFlowRate = 600 [L/min];
            attribute :>> impellerDiameter = 120 [mm];
            attribute :>> efficiency = 0.65;
        }

        part primingSystem : PrimingSystem {
            attribute :>> chamberVolume = 0.6 [L];
        }

        part controlSystem : ControlSystem {
            attribute :>> targetFlowRate = 600 [L/min];
        }

        part structuralFrame : StructuralFrame {
            attribute :>> frameMass = 8.5 [kg];
        }

        connection driveConnection connect engine.shaft to pumpHead.driveShaft;
        connection suctionConnection connect suctionPort to pumpHead.inlet;
        connection dischargeConnection connect pumpHead.outlet to dischargePort;

        assert constraint massCalculation {
            totalMass == 10.5 [kg] + 3.5 [kg] + 0.8 [kg] + structuralFrame.frameMass
        }

        assert constraint efficiencyCalculation {
            overallEfficiency == pumpHead.efficiency * 0.85
        }
    }

    action def StartupSequence {
        in pump : HondaPump;

        first start;
        then action checkFuel {
            assert constraint {
                pump.engine.fuelTank.currentLevel > 0.5 [L]
            }
        }
        then action primePump : PrimingSystem::PrimePump {
            in fluid : Water;
            out primed : Boolean;
        }
        then action startEngine : GasolineEngine::StartEngine {
            in fuelAvailable = true;
            out running : Boolean;
        }
        then action warmUp {
            doc /* Allow engine to reach operating temperature */
        }
        then action rampUpSpeed : GasolineEngine::AdjustThrottle {
            in targetSpeed = 3600 [1/min];
            out actualSpeed : RotationalSpeedValue;
        }
        then done;
    }

    action def PumpingOperation {
        in pump : HondaPump;
        in targetFlowRate : FlowRateValue;
        out actualFlowRate : FlowRateValue;

        first start;
        then merge continuePumping;
        then action monitorConditions {
            out inletPressure : PressureValue;
            out outletPressure : PressureValue;
            out currentFlow : FlowRateValue;
        }
        then action evaluatePerformance : ControlSystem::MonitorPerformance {
            in currentPressure = monitorConditions.outletPressure;
            in currentFlow = monitorConditions.currentFlow;
            out adjustmentNeeded : Boolean;
        }
        then decide;
            if evaluatePerformance.adjustmentNeeded and monitorConditions.currentFlow < targetFlowRate then increaseThrottle;
            if evaluatePerformance.adjustmentNeeded and monitorConditions.currentFlow > targetFlowRate then decreaseThrottle;
            if not evaluatePerformance.adjustmentNeeded then maintainOperation;
        action increaseThrottle : ControlSystem::AdjustThrottle {
            in targetFlow = targetFlowRate;
            in currentFlow = monitorConditions.currentFlow;
            out throttleChange : Real;
        }
        then continuePumping;
        action decreaseThrottle : ControlSystem::AdjustThrottle {
            in targetFlow = targetFlowRate;
            in currentFlow = monitorConditions.currentFlow;
            out throttleChange : Real;
        }
        then continuePumping;
        action maintainOperation {
            doc /* Continue steady-state operation */
        }
        then continuePumping;
    }

    action def ShutdownSequence {
        in pump : HondaPump;

        first start;
        then action reduceThrottle : GasolineEngine::AdjustThrottle {
            in targetSpeed = 1000 [1/min];
            out actualSpeed : RotationalSpeedValue;
        }
        then action idleEngine {
            doc /* Allow engine to cool down at idle */
        }
        then action stopEngine : GasolineEngine::StopEngine {
            out running : Boolean;
        }
        then action drainResidual {
            doc /* Allow residual fluid to drain from pump head */
        }
        then done;
    }

    state def PumpStateMachine {
        entry; then idle;

        state idle {
            entry assign hondaPumpSystem.operatingMode = PumpOperatingMode::off;
        }

        transition idle_to_priming
            first idle
            accept StartCommand
            then priming;

        state priming {
            entry assign hondaPumpSystem.operatingMode = PumpOperatingMode::priming;
            entry do action primingAction : StartupSequence;
        }

        transition priming_to_running
            first priming
            if primingAction.primePump.primed
            then running;

        transition priming_to_fault
            first priming
            if not primingAction.primePump.primed
            then fault;

        state running {
            entry assign hondaPumpSystem.operatingMode = PumpOperatingMode::running;
            do action pumpingAction : PumpingOperation;
        }

        transition running_to_stopping
            first running
            accept StopCommand
            then stopping;

        transition running_to_fault
            first running
            if pumpingAction.monitorConditions.outletPressure > 450000 [Pa]
            then fault;

        state stopping {
            entry assign hondaPumpSystem.operatingMode = PumpOperatingMode::stopping;
            entry do action shutdownAction : ShutdownSequence;
        }

        transition stopping_to_idle
            first stopping
            if shutdownAction.stopEngine.running == false
            then idle;

        state fault {
            entry assign hondaPumpSystem.operatingMode = PumpOperatingMode::fault;
        }

        transition fault_to_idle
            first fault
            accept ResetCommand
            then idle;
    }

    requirement <'REQ-HP-001'> primaryPumpingFunction {
        doc /* The Honda pump system shall transfer water from a low-pressure 
             * source to a high-pressure destination through continuous mechanical 
             * pumping action driven by an integrated gasoline engine, enabling 
             * applications such as irrigation, drainage, and water supply.
             */
        subject hondaPump : HondaPump;

        require flowCapabilityRequirement;
        require pressureCapabilityRequirement;
        require autonomyRequirement;
    }

    requirement <'REQ-HP-002'> flowCapabilityRequirement {
        doc /* The pump shall deliver a minimum flow rate of 600 liters per minute 
             * at rated operating conditions with maximum head of 30 meters.
             */
        subject hondaPump : HondaPump;

        assert constraint {
            hondaPump.ratedFlowRate >= 600 [L/min] and
            hondaPump.maxHead >= 30 [m]
        }
    }

    requirement <'REQ-HP-003'> pressureCapabilityRequirement {
        doc /* The pump shall generate a minimum outlet pressure of 300 kPa 
             * at rated flow conditions.
             */
        subject hondaPump : HondaPump;

        assert constraint {
            hondaPump.ratedPressure >= 300000 [Pa]
        }
    }

    requirement <'REQ-HP-004'> autonomyRequirement {
        doc /* The pump system shall operate continuously for a minimum of 
             * 2 hours at rated flow using the onboard fuel tank.
             */
        subject hondaPump : HondaPump;

        assert constraint {
            hondaPump.engine.fuelTank.capacity >= 
                hondaPump.engine.fuelTank.consumptionRate * 2 [h]
        }
    }

    requirement <'REQ-HP-005'> efficiencyRequirement {
        doc /* The pump shall maintain a minimum overall system efficiency of 
             * 55% at rated operating conditions.
             */
        subject hondaPump : HondaPump;

        assert constraint {
            hondaPump.overallEfficiency >= 0.55
        }
    }

    requirement <'REQ-HP-006'> portabilityRequirement {
        doc /* The total mass of the pump system shall not exceed 25 kg 
             * to ensure portability and ease of deployment.
             */
        subject hondaPump : HondaPump;

        assert constraint {
            hondaPump.totalMass <= 25 [kg]
        }
    }

    requirement <'REQ-HP-007'> reliabilityRequirement {
        doc /* The pump system shall operate reliably for a minimum of 
             * 2000 hours between major maintenance intervals.
             */
        subject hondaPump : HondaPump;
    }

    part hondaPumpSystem : HondaPump {
        attribute :>> operatingMode = PumpOperatingMode::off;
        attribute :>> ratedFlowRate = 600 [L/min];
        attribute :>> ratedPressure = 300000 [Pa];
        attribute :>> maxHead = 30 [m];
        attribute :>> overallEfficiency = 0.55;
        attribute :>> totalMass = 23 [kg];

        part :>> engine {
            attribute :>> currentSpeed = 0 [1/min];
            attribute :>> isRunning = false;
            part :>> fuelTank {
                attribute :>> currentLevel = 3.1 [L];
            }
        }

        part :>> pumpHead {
            part :>> impeller {
                attribute :>> rotationSpeed = 0 [1/min];
            }
        }

        part :>> primingSystem {
            attribute :>> isPrimed = false;
        }

        perform action operationCycle : PumpingOperation {
            in pump = hondaPumpSystem;
            in targetFlowRate = 600 [L/min];
        }

        exhibit state operationStateMachine : PumpStateMachine;
    }

    satisfy primaryPumpingFunction by hondaPumpSystem;
    satisfy flowCapabilityRequirement by hondaPumpSystem;
    satisfy pressureCapabilityRequirement by hondaPumpSystem;
    satisfy autonomyRequirement by hondaPumpSystem;
    satisfy efficiencyRequirement by hondaPumpSystem;
    satisfy portabilityRequirement by hondaPumpSystem;
    satisfy reliabilityRequirement by hondaPumpSystem;
}
