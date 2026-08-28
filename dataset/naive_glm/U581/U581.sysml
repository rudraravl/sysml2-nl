package WaterladderPumpingSubsystem {

    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    // ===== Value type definitions with units =====
    value def TorqueValue :> Real {
        attribute unit : String = "N·m";
    }
    value def RotationalSpeedValue :> Real {
        attribute unit : String = "rpm";
    }
    value def FlowRateValue :> Real {
        attribute unit : String = "L/s";
    }
    value def PressureValue :> Real {
        attribute unit : String = "bar";
    }
    value def ElevationValue :> Real {
        attribute unit : String = "m";
    }
    value def VolumeValue :> Real {
        attribute unit : String = "L";
    }
    value def VoltageValue :> Real {
        attribute unit : String = "V";
    }
    value def CurrentValue :> Real {
        attribute unit : String = "A";
    }
    value def PowerValue :> Real {
        attribute unit : String = "W";
    }
    value def EfficiencyValue :> Real {
        attribute unit : String = "%";
    }
    value def TimeValue :> Real {
        attribute unit : String = "s";
    }

    // ===== Item definitions =====
    item def Water;
    item def ElectricalPower;
    item def MechanicalPower;

    // ===== Port definitions =====
    port def WaterFlowPort {
        attribute nominalFlowRate : FlowRateValue;
        attribute pressure : PressureValue;
        flow water : Water;
    }
    port def ElectricalPort {
        attribute voltage : VoltageValue;
        attribute current : CurrentValue;
        flow power : ElectricalPower;
    }
    port def MechanicalDrivePort {
        attribute torque : TorqueValue;
        attribute speed : RotationalSpeedValue;
        flow power : MechanicalPower;
    }
    port def CommandPort {
        attribute commandType : String;
    }
    port def StatusPort {
        attribute systemState : String;
        attribute systemActive : Boolean;
    }
    port def PressureSensorPort {
        attribute measuredPressure : PressureValue;
    }
    port def FlowSensorPort {
        attribute measuredFlowRate : FlowRateValue;
    }
    port def TorqueSensorPort {
        attribute measuredTorque : TorqueValue;
    }

    // ===== State machine definition =====
    state def PumpSystemStateMachine {
        attribute receivedCommand : String = "";
        attribute motorTorqueValue : TorqueValue = 0.0;
        attribute maxTorqueLimit : TorqueValue = 200.0;
        attribute currentSpeed : RotationalSpeedValue = 0.0;
        attribute operationalSpeedValue : RotationalSpeedValue = 60.0;

        state stopped {
            entry assign currentSpeed = 0;
        }
        state starting {
            entry assign currentSpeed = currentSpeed + 1;
        }
        state running {
            entry assign currentSpeed = operationalSpeedValue;
        }
        state stopping {
            entry assign currentSpeed = currentSpeed - 1;
        }
        state fault {
            entry assign currentSpeed = 0;
        }

        transition startFromStopped
            from stopped to starting
            when receivedCommand == "start";
        transition reachOperationalSpeed
            from starting to running
            when currentSpeed >= operationalSpeedValue;
        transition stopFromRunning
            from running to stopping
            when receivedCommand == "stop";
        transition reachedStopped
            from stopping to stopped
            when currentSpeed <= 0;
        transition faultFromRunning
            from running to fault
            when motorTorqueValue > maxTorqueLimit;
        transition faultFromStarting
            from starting to fault
            when motorTorqueValue > maxTorqueLimit;
        transition faultFromStopping
            from stopping to fault
            when motorTorqueValue > maxTorqueLimit;
        transition resetFromFault
            from fault to stopped
            when receivedCommand == "reset";
    }

    // ===== Component part definitions =====
    part def SupplyReservoir {
        attribute waterLevel : ElevationValue = 2.0;
        attribute maximumCapacity : VolumeValue = 50000;
        attribute minimumLevel : ElevationValue = 0.5;
        attribute currentVolume : VolumeValue = 40000;
        port outlet : WaterFlowPort;
        action supplyWater {
            assign outlet.nominalFlowRate = 40.0;
            assign outlet.pressure = 1.0;
        }
    }

    part def DischargeReservoir {
        attribute waterLevel : ElevationValue = 0.0;
        attribute maximumCapacity : VolumeValue = 30000;
        attribute elevationAboveSupply : ElevationValue = 12.0;
        attribute currentVolume : VolumeValue = 0.0;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        action receiveWater {
            assign currentVolume = currentVolume + inlet.nominalFlowRate;
            assign waterLevel = currentVolume / 2500.0;
        }
    }

    part def InletControlValve {
        attribute isOpen : Boolean = false;
        attribute openingFraction : Real = 0.0;
        attribute maximumFlowRate : FlowRateValue = 50.0;
        attribute nominalPressureDrop : PressureValue = 0.1;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        port control : CommandPort;
        action open {
            assign isOpen = true;
            assign openingFraction = 1.0;
            assign outlet.nominalFlowRate = inlet.nominalFlowRate;
            assign outlet.pressure = inlet.pressure - nominalPressureDrop;
        }
        action close {
            assign isOpen = false;
            assign openingFraction = 0.0;
            assign outlet.nominalFlowRate = 0.0;
        }
        action setOpening(fraction : Real) {
            assign openingFraction = fraction;
            assign isOpen = (fraction > 0.0);
            assign outlet.nominalFlowRate = inlet.nominalFlowRate * fraction;
        }
    }

    part def DriveMotor {
        attribute ratedPower : PowerValue = 15000;
        attribute ratedVoltage : VoltageValue = 400;
        attribute ratedCurrent : CurrentValue = 40;
        attribute ratedTorque : TorqueValue = 150;
        attribute ratedSpeed : RotationalSpeedValue = 60;
        attribute actualTorque : TorqueValue = 0.0;
        attribute actualSpeed : RotationalSpeedValue = 0.0;
        attribute isEnergized : Boolean = false;
        port electricalInput : ElectricalPort;
        port mechanicalOutput : MechanicalDrivePort;
        port torqueOutput : TorqueSensorPort;
        port control : CommandPort;
        action energize {
            assign isEnergized = true;
            assign actualTorque = ratedTorque;
        }
        action deenergize {
            assign isEnergized = false;
            assign actualTorque = 0.0;
            assign actualSpeed = 0.0;
        }
        action accelerateTo(targetSpeed : RotationalSpeedValue) {
            assign actualSpeed = targetSpeed;
        }
        action convertElectricalToMechanical {
            assign mechanicalOutput.torque = actualTorque;
            assign mechanicalOutput.speed = actualSpeed;
            assign torqueOutput.measuredTorque = actualTorque;
        }
    }

    part def Drum {
        attribute radius : ElevationValue = 0.8;
        attribute rotationalSpeed : RotationalSpeedValue = 0.0;
        port driveInput : MechanicalDrivePort;
        port chainInterface : MechanicalDrivePort;
        action rotate {
            assign rotationalSpeed = driveInput.speed;
            assign chainInterface.speed = rotationalSpeed;
            assign chainInterface.torque = driveInput.torque;
        }
    }

    part def Chain {
        attribute totalLength : ElevationValue = 30.0;
        attribute linkCount : Integer = 480;
        port driveEnd : MechanicalDrivePort;
        port bucketAttachments : MechanicalDrivePort[12];
        action transmitMotion {
            assign bucketAttachments[*].speed = driveEnd.speed;
            assign bucketAttachments[*].torque = driveEnd.torque;
        }
    }

    part def Bucket {
        attribute capacity : VolumeValue = 5.0;
        attribute isFull : Boolean = false;
        attribute fillLevel : Real = 0.0;
        port attachPoint : MechanicalDrivePort;
        action fill {
            assign isFull = true;
            assign fillLevel = 1.0;
        }
        action tiltAndDischarge {
            assign isFull = false;
            assign fillLevel = 0.0;
        }
    }

    part def WaterladderPump {
        attribute bucketCount : Integer = 12;
        attribute liftHeight : ElevationValue = 12.0;
        attribute nominalFlowRate : FlowRateValue = 40.0;
        attribute bucketVolume : VolumeValue = 5.0;
        attribute chainSpeed : ElevationValue = 0.5;
        attribute operationalEfficiency : EfficiencyValue = 75.0;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        port driveInput : MechanicalDrivePort;
        port inletPressurePoint : PressureSensorPort;
        port outletPressurePoint : PressureSensorPort;

        part drum : Drum;
        part chain : Chain;
        part buckets : Bucket[12];

        connection drumDrive
            connect driveInput to drum.driveInput;
        connection drumToChain
            connect drum.chainInterface to chain.driveEnd;
        connection chainToBucket1
            connect chain.bucketAttachments[1] to buckets[1].attachPoint;
        connection chainToBucket2
            connect chain.bucketAttachments[2] to buckets[2].attachPoint;
        connection chainToBucket3
            connect chain.bucketAttachments[3] to buckets[3].attachPoint;
        connection chainToBucket4
            connect chain.bucketAttachments[4] to buckets[4].attachPoint;
        connection chainToBucket5
            connect chain.bucketAttachments[5] to buckets[5].attachPoint;
        connection chainToBucket6
            connect chain.bucketAttachments[6] to buckets[6].attachPoint;
        connection chainToBucket7
            connect chain.bucketAttachments[7] to buckets[7].attachPoint;
        connection chainToBucket8
            connect chain.bucketAttachments[8] to buckets[8].attachPoint;
        connection chainToBucket9
            connect chain.bucketAttachments[9] to buckets[9].attachPoint;
        connection chainToBucket10
            connect chain.bucketAttachments[10] to buckets[10].attachPoint;
        connection chainToBucket11
            connect chain.bucketAttachments[11] to buckets[11].attachPoint;
        connection chainToBucket12
            connect chain.bucketAttachments[12] to buckets[12].attachPoint;

        action liftWater {
            fillBuckets;
            then liftBuckets;
            then dischargeBuckets;
        }
        action fillBuckets {
            assign buckets[*].fillLevel = 1.0;
            assign buckets[*].isFull = true;
            assign inletPressurePoint.measuredPressure = inlet.pressure;
        }
        action liftBuckets {
            assign drum.rotationalSpeed = driveInput.speed;
            assign chain.driveEnd.speed = drum.chainInterface.speed;
            assign chain.driveEnd.torque = drum.chainInterface.torque;
        }
        action dischargeBuckets {
            assign buckets[*].fillLevel = 0.0;
            assign buckets[*].isFull = false;
            assign outlet.nominalFlowRate = nominalFlowRate;
            assign outletPressurePoint.measuredPressure = outlet.pressure;
        }
        action updatePressurePoints {
            assign inletPressurePoint.measuredPressure = inlet.pressure;
            assign outletPressurePoint.measuredPressure = outlet.pressure;
        }
    }

    part def PressureGauge {
        attribute measurementRange : PressureValue = 10.0;
        attribute accuracy : Real = 0.01;
        attribute measuredPressure : PressureValue = 0.0;
        port sensingPort : PressureSensorPort;
        port reading : PressureSensorPort;
        action measure {
            assign measuredPressure = sensingPort.measuredPressure;
            assign reading.measuredPressure = measuredPressure;
        }
    }

    part def FlowMeter {
        attribute measurementRange : FlowRateValue = 100.0;
        attribute accuracy : Real = 0.02;
        attribute measuredFlowRate : FlowRateValue = 0.0;
        attribute totalVolumePassed : VolumeValue = 0.0;
        port inlet : WaterFlowPort;
        port outlet : WaterFlowPort;
        port reading : FlowSensorPort;
        action measure {
            assign measuredFlowRate = inlet.nominalFlowRate;
            assign reading.measuredFlowRate = measuredFlowRate;
            assign outlet.nominalFlowRate = measuredFlowRate;
            assign outlet.pressure = inlet.pressure;
        }
        action accumulateVolume {
            assign totalVolumePassed = totalVolumePassed + measuredFlowRate;
        }
    }

    part def PumpController {
        attribute maxTorque : TorqueValue = 200.0;
        attribute faultTorqueThreshold : TorqueValue = 200.0;
        attribute startAccelerationTime : TimeValue = 10.0;
        attribute stopDecelerationTime : TimeValue = 15.0;
        attribute operationalSpeed : RotationalSpeedValue = 60.0;
        attribute currentState : String = "stopped";
        attribute lastCommand : String = "";
        attribute motorTorqueReading : TorqueValue = 0.0;
        attribute inletPressureReading : PressureValue = 0.0;
        attribute outletPressureReading : PressureValue = 0.0;
        attribute dischargeFlowReading : FlowRateValue = 0.0;

        port commandInput : CommandPort;
        port statusOutput : StatusPort;
        port inletPressureInput : PressureSensorPort;
        port outletPressureInput : PressureSensorPort;
        port flowInput : FlowSensorPort;
        port torqueInput : TorqueSensorPort;
        port motorPowerOutput : ElectricalPort;
        port valveCommandOutput : CommandPort;
        port motorCommandOutput : CommandPort;

        action sendMotorPower {
            assign motorPowerOutput.voltage = 400;
            assign motorPowerOutput.current = 40;
        }
        action cutMotorPower {
            assign motorPowerOutput.voltage = 0;
            assign motorPowerOutput.current = 0;
        }
        action openInletValve {
            assign valveCommandOutput.commandType = "open";
        }
        action closeInletValve {
            assign valveCommandOutput.commandType = "close";
        }
        action sendMotorStart {
            assign motorCommandOutput.commandType = "start";
        }
        action sendMotorStop {
            assign motorCommandOutput.commandType = "stop";
        }
        action monitorSensors {
            assign inletPressureReading = inletPressureInput.measuredPressure;
            assign outletPressureReading = outletPressureInput.measuredPressure;
            assign dischargeFlowReading = flowInput.measuredFlowRate;
            assign motorTorqueReading = torqueInput.measuredTorque;
        }
        action reportStatus {
            assign statusOutput.systemState = currentState;
            assign statusOutput.systemActive = (currentState == "running");
        }
        action processCommand {
            assign lastCommand = commandInput.commandType;
        }
        action clearFault {
            assign currentState = "stopped";
            assign lastCommand = "";
        }
        exhibit operation : PumpSystemStateMachine;
    }

    // ===== Top-level subsystem =====
    part def WaterladderPumpingSubsystem {
        attribute manufacturer : String = "HydroTech Systems";
        attribute modelNumber : String = "WL-5000";
        attribute systemCapacity : VolumeValue = 50000;
        attribute maxLiftHeight : ElevationValue = 15.0;
        attribute designFlowRate : FlowRateValue = 40.0;

        port externalCommand : CommandPort;
        port externalStatus : StatusPort;

        part supplyReservoir : SupplyReservoir;
        part inletControlValve : InletControlValve;
        part waterladderPump : WaterladderPump;
        part driveMotor : DriveMotor;
        part dischargeReservoir : DischargeReservoir;
        part inletPressureGauge : PressureGauge;
        part outletPressureGauge : PressureGauge;
        part flowMeter : FlowMeter;
        part controller : PumpController;

        // Water flow path connections
        connection waterFromSupply
            connect supplyReservoir.outlet to inletControlValve.inlet;
        connection waterToPump
            connect inletControlValve.outlet to waterladderPump.inlet;
        connection waterToFlowMeter
            connect waterladderPump.outlet to flowMeter.inlet;
        connection waterToDischarge
            connect flowMeter.outlet to dischargeReservoir.inlet;

        // Mechanical power connection
        connection motorDrive
            connect driveMotor.mechanicalOutput to waterladderPump.driveInput;

        // Electrical power connection
        connection electricalSupply
            connect controller.motorPowerOutput to driveMotor.electricalInput;

        // Pressure sensing connections
        connection inletPressureSensing
            connect waterladderPump.inletPressurePoint to inletPressureGauge.sensingPort;
        connection outletPressureSensing
            connect waterladderPump.outletPressurePoint to outletPressureGauge.sensingPort;
        connection inletPressureSignal
            connect inletPressureGauge.reading to controller.inletPressureInput;
        connection outletPressureSignal
            connect outletPressureGauge.reading to controller.outletPressureInput;

        // Flow and torque signal connections
        connection flowSignal
            connect flowMeter.reading to controller.flowInput;
        connection torqueSignal
            connect driveMotor.torqueOutput to controller.torqueInput;

        // Control connections
        connection externalControlCmd
            connect externalCommand to controller.commandInput;
        connection valveControlCmd
            connect controller.valveCommandOutput to inletControlValve.control;
        connection motorControlCmd
            connect controller.motorCommandOutput to driveMotor.control;

        // Status connection
        connection systemStatusOut
            connect controller.statusOutput to externalStatus;

        exhibit systemOperation : PumpSystemStateMachine;
    }

    // ===== Requirements =====
    requirement def WaterladderSystemRequirements {
        subject system : WaterladderPumpingSubsystem;
        doc {
            Requirements for the waterladder pumping subsystem
            designed for continuous, efficient, and reliable water lifting
            from a low-level supply reservoir to a higher discharge reservoir.
        }
    }

    requirement ContinuousReliableOperation :> WaterladderSystemRequirements {
        doc {
            The system shall be designed for continuous, efficient,
            and reliable operation.
        }
        attribute minUptimePercentage : EfficiencyValue = 99.5;
    }

    requirement WaterLiftingFunction :> WaterladderSystemRequirements {
        doc {
            The system shall lift water from a low-level supply reservoir
            to a higher discharge reservoir.
        }
        attribute minLiftHeight : ElevationValue = 12.0;
    }

    requirement BucketDesignRequirement :> WaterladderSystemRequirements {
        doc {
            The waterladder pump shall use a series of 12 buckets
            attached to a continuous lifting chain.
        }
        attribute bucketCount : Integer = 12;
        attribute bucketCapacity : VolumeValue = 5.0;
    }

    requirement DrumMechanismRequirement :> WaterladderSystemRequirements {
        doc {
            The chain shall be looped around a large rotating drum that
            pulls the chain as it turns, causing buckets to dip into
            the water at the inlet, fill up, and be lifted vertically.
        }
    }

    requirement BucketTiltDischargeRequirement :> WaterladderSystemRequirements {
        doc {
            At the top of their travel, the buckets shall tilt and
            discharge water into the outlet pipe.
        }
    }

    requirement DriveMotorRequirement :> WaterladderSystemRequirements {
        doc {
            A dedicated drive motor shall convert electrical power into
            the mechanical torque and rotational speed needed to turn
            the pump drum.
        }
        attribute ratedPower : PowerValue = 15000;
        attribute ratedVoltage : VoltageValue = 400;
    }

    requirement InletValveRegulation :> WaterladderSystemRequirements {
        doc {
            An inlet control valve shall be situated between the supply
            reservoir and the pump to regulate the incoming water flow.
        }
        attribute maxFlowRate : FlowRateValue = 50.0;
    }

    requirement PressureGaugesRequirement :> WaterladderSystemRequirements {
        doc {
            Pressure gauges shall be installed at the pump inlet and
            outlet to monitor performance.
        }
        attribute gaugeCount : Integer = 2;
        attribute gaugeAccuracy : Real = 0.01;
    }

    requirement FlowMeterRequirement :> WaterladderSystemRequirements {
        doc {
            A flow meter shall measure the volume of water being moved
            to the discharge reservoir.
        }
        attribute meterAccuracy : Real = 0.02;
    }

    requirement StateMachineOperation :> WaterladderSystemRequirements {
        doc {
            The system operation shall be managed through a series of
            states: stopped, starting, running, stopping, and fault.
        }
    }

    requirement StartCommandRequirement :> WaterladderSystemRequirements {
        doc {
            The system shall remain in a stopped state until it receives
            a start command. Upon receiving the command, it shall enter
            a starting sequence to gradually accelerate to operational speed.
        }
    }

    requirement RunningStateRequirement :> WaterladderSystemRequirements {
        doc {
            During the running state, the system shall continuously lift
            and discharge water.
        }
    }

    requirement StopCommandRequirement :> WaterladderSystemRequirements {
        doc {
            A stop command shall initiate a stopping sequence to safely
            decelerate the system to a stopped state.
        }
    }

    requirement FaultStateProtection :> WaterladderSystemRequirements {
        doc {
            The system shall enter a fault state and shut down if it
            detects excessive motor torque, which could indicate a
            blockage or mechanical failure.
        }
        attribute maxTorque : TorqueValue = 200.0;
    }

    requirement ManualResetRequirement :> WaterladderSystemRequirements {
        doc {
            A manual reset shall be required to clear the fault and
            return the system to a stopped state.
        }
    }

    requirement SystemEfficiencyRequirement :> WaterladderSystemRequirements {
        doc {
            The overall system shall achieve a minimum pumping efficiency
            of 75 percent during continuous operation.
        }
        attribute minEfficiency : EfficiencyValue = 75.0;
    }

    requirement SupplyReservoirRequirement :> WaterladderSystemRequirements {
        doc {
            A supply reservoir shall be provided at a low level from
            which water is drawn.
        }
        attribute minCapacity : VolumeValue = 50000;
    }

    requirement DischargeReservoirRequirement :> WaterladderSystemRequirements {
        doc {
            A discharge reservoir shall be located at a higher elevation
            where the lifted water is deposited.
        }
        attribute minElevationAboveSupply : ElevationValue = 12.0;
        attribute minCapacity : VolumeValue = 30000;
    }
}
