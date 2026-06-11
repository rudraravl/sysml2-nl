package RoundaboutPlayPumpSubsystem {

    import ScalarValues::*;
    import SI::*;

    attribute def FlowRate :> Real {
        unit = "L/min";
    }

    attribute def Pressure :> Real {
        unit = "kPa";
    }

    attribute def Volume :> Real {
        unit = "L";
    }

    attribute def RotationalSpeed :> Real {
        unit = "rpm";
    }

    attribute def Torque :> Real {
        unit = "N*m";
    }

    attribute def Power :> Real {
        unit = "W";
    }

    attribute def TimeDuration :> Real {
        unit = "s";
    }

    attribute def Length :> Real {
        unit = "m";
    }

    attribute def Efficiency :> Real {
        unit = "1";
    }

    attribute def PersonCount :> Integer {
        unit = "person";
    }

    item def Groundwater {
        attribute turbidity : Real;
        attribute temperature : Real;
        attribute sourceDepth : Length;
    }

    item def PumpedWater :> Groundwater {
        attribute deliveryPressure : Pressure;
        attribute deliveredFlow : FlowRate;
    }

    item def RotaryMechanicalPower {
        attribute speed : RotationalSpeed;
        attribute torque : Torque;
        attribute power : Power;
    }

    item def ReciprocatingMechanicalPower {
        attribute strokeRate : Real;
        attribute strokeLength : Length;
        attribute axialForce : Real;
    }

    item def OperationalStatus {
        attribute available : Boolean;
        attribute faulted : Boolean;
        attribute operatingHours : TimeDuration;
    }

    port def WaterInletPort {
        in item waterIn : Groundwater;
    }

    port def WaterOutletPort {
        out item waterOut : PumpedWater;
    }

    port def RotaryDrivePort {
        out item rotaryPower : RotaryMechanicalPower;
    }

    port def RotaryReceivePort {
        in item rotaryPower : RotaryMechanicalPower;
    }

    port def ReciprocatingDrivePort {
        out item reciprocatingPower : ReciprocatingMechanicalPower;
    }

    port def ReciprocatingReceivePort {
        in item reciprocatingPower : ReciprocatingMechanicalPower;
    }

    port def StatusPort {
        out item status : OperationalStatus;
    }

    port def HumanInteractionPort {
        in attribute riders : PersonCount;
        in attribute appliedTangentialForce : Real;
    }

    part def RoundaboutPlayPump {
        attribute nominalDiameter : Length = 2.2;
        attribute minimumRiders : PersonCount = 2;
        attribute maximumRiders : PersonCount = 12;
        attribute nominalSpeed : RotationalSpeed = 18.0;
        attribute maximumSpeed : RotationalSpeed = 32.0;
        attribute minimumUsefulSpeed : RotationalSpeed = 8.0;
        attribute rotationalInertia : Real = 145.0;

        port riderInput : HumanInteractionPort;
        port driveOutput : RotaryDrivePort;
        port statusOutput : StatusPort;

        action generateRotation {
            in riders : PersonCount;
            in appliedTangentialForce : Real;
            out rotaryPower : RotaryMechanicalPower;

            first start;
            then validateLoad;
            then accelerate;
            then regulateSpeed;
            then emitPower;

            action validateLoad {
                in riders : PersonCount;
                out enabled : Boolean;
            }

            action accelerate {
                in appliedTangentialForce : Real;
                out speed : RotationalSpeed;
                out torque : Torque;
            }

            action regulateSpeed {
                in speed : RotationalSpeed;
                out regulatedSpeed : RotationalSpeed;
            }

            action emitPower {
                in regulatedSpeed : RotationalSpeed;
                in torque : Torque;
                out rotaryPower : RotaryMechanicalPower;
            }
        }

        state playPumpOperating {
            state Idle;
            state BeingPushed;
            state UsefulRotation;
            state OverspeedLimited;
            state StoppedForInspection;

            initial then Idle;

            transition Idle_to_BeingPushed
                first Idle
                accept when riderInput.riders >= minimumRiders
                then BeingPushed;

            transition BeingPushed_to_UsefulRotation
                first BeingPushed
                accept when driveOutput.rotaryPower.speed >= minimumUsefulSpeed
                then UsefulRotation;

            transition UsefulRotation_to_OverspeedLimited
                first UsefulRotation
                accept when driveOutput.rotaryPower.speed > maximumSpeed
                then OverspeedLimited;

            transition OverspeedLimited_to_UsefulRotation
                first OverspeedLimited
                accept when driveOutput.rotaryPower.speed <= nominalSpeed
                then UsefulRotation;

            transition UsefulRotation_to_Idle
                first UsefulRotation
                accept when riderInput.riders < minimumRiders
                then Idle;

            transition any_to_Inspection
                first Idle
                accept when statusOutput.status.faulted
                then StoppedForInspection;
        }
    }

    part def SpeedLimiter {
        attribute maximumAllowedSpeed : RotationalSpeed = 32.0;
        attribute frictionBrakeTorque : Torque = 18.0;

        port rotaryInput : RotaryReceivePort;
        port rotaryOutput : RotaryDrivePort;

        action limitRotationalSpeed {
            in incomingPower : RotaryMechanicalPower;
            out limitedPower : RotaryMechanicalPower;
        }
    }

    part def GearboxAndCrank {
        attribute gearRatio : Real = 3.5;
        attribute crankRadius : Length = 0.16;
        attribute mechanicalEfficiency : Efficiency = 0.82;
        attribute nominalStrokeLength : Length = 0.32;

        port rotaryInput : RotaryReceivePort;
        port reciprocatingOutput : ReciprocatingDrivePort;

        action convertRotationToStroke {
            in rotaryPower : RotaryMechanicalPower;
            out reciprocatingPower : ReciprocatingMechanicalPower;
        }
    }

    part def BoreholeRiser {
        attribute boreholeDepth : Length = 45.0;
        attribute staticWaterLevel : Length = 18.0;
        attribute drawdownAllowance : Length = 7.0;
        attribute riserPipeDiameter : Length = 0.04;
        attribute footValveCrackingPressure : Pressure = 12.0;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
    }

    part def ReciprocatingPumpCylinder {
        attribute cylinderDiameter : Length = 0.075;
        attribute strokeLength : Length = 0.32;
        attribute volumetricEfficiency : Efficiency = 0.74;
        attribute maximumDischargePressure : Pressure = 650.0;
        attribute nominalFlowRate : FlowRate = 18.0;
        attribute minimumFlowRate : FlowRate = 6.0;

        port waterInlet : WaterInletPort;
        port waterOutlet : WaterOutletPort;
        port mechanicalInput : ReciprocatingReceivePort;
        port statusOutput : StatusPort;

        action pumpWater {
            in sourceWater : Groundwater;
            in reciprocatingPower : ReciprocatingMechanicalPower;
            out deliveredWater : PumpedWater;
        }

        state pumpState {
            state Priming;
            state Ready;
            state Pumping;
            state LowSpeedNoDelivery;
            state BlockedOutlet;
            state MaintenanceRequired;

            initial then Priming;

            transition Priming_to_Ready
                first Priming
                accept when waterInlet.waterIn.sourceDepth <= 52.0
                then Ready;

            transition Ready_to_Pumping
                first Ready
                accept when mechanicalInput.reciprocatingPower.strokeRate >= 10.0
                then Pumping;

            transition Pumping_to_LowSpeed
                first Pumping
                accept when mechanicalInput.reciprocatingPower.strokeRate < 10.0
                then LowSpeedNoDelivery;

            transition LowSpeed_to_Pumping
                first LowSpeedNoDelivery
                accept when mechanicalInput.reciprocatingPower.strokeRate >= 10.0
                then Pumping;

            transition Pumping_to_BlockedOutlet
                first Pumping
                accept when waterOutlet.waterOut.deliveryPressure > maximumDischargePressure
                then BlockedOutlet;

            transition BlockedOutlet_to_Maintenance
                first BlockedOutlet
                accept after 60.0
                then MaintenanceRequired;
        }
    }

    part def DeliveryPipe {
        attribute length : Length = 32.0;
        attribute internalDiameter : Length = 0.032;
        attribute nominalPressureLoss : Pressure = 38.0;
        attribute burstPressure : Pressure = 1200.0;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
    }

    part def StorageTank {
        attribute capacity : Volume = 2500.0;
        attribute minimumReserveVolume : Volume = 500.0;
        attribute overflowLevel : Volume = 2450.0;
        attribute currentVolume : Volume = 1000.0;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;
        port statusOutput : StatusPort;

        action storeWater {
            in incomingWater : PumpedWater;
            out storedVolume : Volume;
        }

        state tankState {
            state LowReserve;
            state NormalStorage;
            state Overflowing;

            initial then NormalStorage;

            transition Normal_to_Low
                first NormalStorage
                accept when currentVolume < minimumReserveVolume
                then LowReserve;

            transition Low_to_Normal
                first LowReserve
                accept when currentVolume >= minimumReserveVolume
                then NormalStorage;

            transition Normal_to_Overflow
                first NormalStorage
                accept when currentVolume >= overflowLevel
                then Overflowing;

            transition Overflow_to_Normal
                first Overflowing
                accept when currentVolume < overflowLevel
                then NormalStorage;
        }
    }

    part def OutletTapStand {
        attribute tapHeight : Length = 0.9;
        attribute maximumUserFlow : FlowRate = 22.0;
        attribute minimumUsefulPressure : Pressure = 20.0;

        port inlet : WaterInletPort;
        port outlet : WaterOutletPort;

        action dispenseWater {
            in storedWater : PumpedWater;
            out userWater : PumpedWater;
        }
    }

    part def MaintenanceMonitor {
        attribute inspectionInterval : TimeDuration = 2592000.0;
        attribute maximumContinuousOverspeedTime : TimeDuration = 30.0;
        attribute sealReplacementInterval : TimeDuration = 15552000.0;
        attribute bearingReplacementInterval : TimeDuration = 31104000.0;

        port playPumpStatus : StatusPort;
        port pumpStatus : StatusPort;
        port tankStatus : StatusPort;

        action evaluateHealth {
            in playPumpStatus : OperationalStatus;
            in pumpStatus : OperationalStatus;
            in tankStatus : OperationalStatus;
            out subsystemAvailable : Boolean;
        }
    }

    part def RoundaboutPlayPumpPumpingSubsystem {
        attribute designLife : TimeDuration = 315360000.0;
        attribute nominalDailyWaterVolume : Volume = 3000.0;
        attribute peakFlowRate : FlowRate = 24.0;
        attribute nominalDeliveredFlowRate : FlowRate = 18.0;
        attribute maximumBoreholeDepth : Length = 52.0;
        attribute minimumUsefulRoundaboutSpeed : RotationalSpeed = 8.0;
        attribute maximumSafeRoundaboutSpeed : RotationalSpeed = 32.0;

        part roundabout : RoundaboutPlayPump;
        part limiter : SpeedLimiter;
        part transmission : GearboxAndCrank;
        part borehole : BoreholeRiser;
        part pump : ReciprocatingPumpCylinder;
        part deliveryPipe : DeliveryPipe;
        part storageTank : StorageTank;
        part tapStand : OutletTapStand;
        part monitor : MaintenanceMonitor;

        port groundwaterSource : WaterInletPort;
        port publicWaterOutlet : WaterOutletPort;
        port userInteraction : HumanInteractionPort;
        port subsystemStatus : StatusPort;

        connect userInteraction to roundabout.riderInput;
        connect roundabout.driveOutput to limiter.rotaryInput;
        connect limiter.rotaryOutput to transmission.rotaryInput;
        connect transmission.reciprocatingOutput to pump.mechanicalInput;

        connect groundwaterSource to borehole.inlet;
        connect borehole.outlet to pump.waterInlet;
        connect pump.waterOutlet to deliveryPipe.inlet;
        connect deliveryPipe.outlet to storageTank.inlet;
        connect storageTank.outlet to tapStand.inlet;
        connect tapStand.outlet to publicWaterOutlet;

        connect roundabout.statusOutput to monitor.playPumpStatus;
        connect pump.statusOutput to monitor.pumpStatus;
        connect storageTank.statusOutput to monitor.tankStatus;
        connect monitor.playPumpStatus to subsystemStatus;

        action operateSubsystem {
            in riders : PersonCount;
            in sourceWater : Groundwater;
            out deliveredWater : PumpedWater;

            first acceptRiderInput;
            then generateRoundaboutPower;
            then limitSpeed;
            then convertMotion;
            then liftWater;
            then deliverToTank;
            then supplyTapStand;

            action acceptRiderInput {
                in riders : PersonCount;
                out enabled : Boolean;
            }

            action generateRoundaboutPower {
                in enabled : Boolean;
                out rotaryPower : RotaryMechanicalPower;
            }

            action limitSpeed {
                in rotaryPower : RotaryMechanicalPower;
                out limitedPower : RotaryMechanicalPower;
            }

            action convertMotion {
                in limitedPower : RotaryMechanicalPower;
                out reciprocatingPower : ReciprocatingMechanicalPower;
            }

            action liftWater {
                in sourceWater : Groundwater;
                in reciprocatingPower : ReciprocatingMechanicalPower;
                out pumpedWater : PumpedWater;
            }

            action deliverToTank {
                in pumpedWater : PumpedWater;
                out tankWater : PumpedWater;
            }

            action supplyTapStand {
                in tankWater : PumpedWater;
                out deliveredWater : PumpedWater;
            }
        }

        state subsystemLifecycle {
            state Installed;
            state Available;
            state Pumping;
            state Standby;
            state Degraded;
            state OutOfService;

            initial then Installed;

            transition Installed_to_Available
                first Installed
                accept when monitor.playPumpStatus.status.available
                then Available;

            transition Available_to_Pumping
                first Available
                accept when roundabout.driveOutput.rotaryPower.speed >= minimumUsefulRoundaboutSpeed
                then Pumping;

            transition Pumping_to_Standby
                first Pumping
                accept when roundabout.driveOutput.rotaryPower.speed < minimumUsefulRoundaboutSpeed
                then Standby;

            transition Standby_to_Pumping
                first Standby
                accept when roundabout.driveOutput.rotaryPower.speed >= minimumUsefulRoundaboutSpeed
                then Pumping;

            transition Pumping_to_Degraded
                first Pumping
                accept when pump.waterOutlet.waterOut.deliveredFlow < pump.minimumFlowRate
                then Degraded;

            transition Degraded_to_OutOfService
                first Degraded
                accept when monitor.pumpStatus.status.faulted
                then OutOfService;

            transition OutOfService_to_Available
                first OutOfService
                accept when not monitor.pumpStatus.status.faulted
                then Available;
        }

        constraint flowCapacity {
            pump.nominalFlowRate >= nominalDeliveredFlowRate;
            peakFlowRate <= tapStand.maximumUserFlow + 2.0;
        }

        constraint safeOperation {
            roundabout.maximumSpeed <= maximumSafeRoundaboutSpeed;
            roundabout.minimumUsefulSpeed >= minimumUsefulRoundaboutSpeed;
            pump.maximumDischargePressure < deliveryPipe.burstPressure;
        }

        constraint boreholeCompatibility {
            borehole.boreholeDepth <= maximumBoreholeDepth;
            borehole.staticWaterLevel + borehole.drawdownAllowance < maximumBoreholeDepth;
        }

        constraint tankSizing {
            storageTank.capacity >= storageTank.minimumReserveVolume;
            storageTank.overflowLevel < storageTank.capacity;
            nominalDailyWaterVolume <= storageTank.capacity * 1.5;
        }
    }

    requirement def MoveFluidRequirement {
        doc
        /* The subsystem shall move groundwater from a borehole to a public outlet using mechanical energy supplied by a child-safe roundabout PlayPump. */
    }

    requirement def HumanPoweredOperationRequirement {
        doc
        /* The subsystem shall require no grid electricity, engine fuel, or battery power for normal pumping operation. */
    }

    requirement def MinimumFlowRequirement {
        attribute requiredFlow : FlowRate = 6.0;
        doc
        /* The subsystem shall deliver at least the required flow rate when the roundabout rotates at or above the minimum useful speed and the borehole depth is within the specified limit. */
    }

    requirement def SafeSpeedRequirement {
        attribute maximumAllowedSpeed : RotationalSpeed = 32.0;
        doc
        /* The roundabout shall limit rotational speed to protect riders and pumping equipment. */
    }

    requirement def BoreholeDepthRequirement {
        attribute maximumDepth : Length = 52.0;
        doc
        /* The pump shall lift water from boreholes up to the maximum specified depth including drawdown allowance. */
    }

    requirement def StorageRequirement {
        attribute minimumReserve : Volume = 500.0;
        attribute tankCapacity : Volume = 2500.0;
        doc
        /* The subsystem shall store pumped water in a raised or protected tank with reserve and overflow management. */
    }

    requirement def MaintainabilityRequirement {
        attribute inspectionInterval : TimeDuration = 2592000.0;
        doc
        /* The subsystem shall provide operating status sufficient to schedule inspection at least once per inspection interval. */
    }

    requirement def PublicOutletRequirement {
        attribute minimumPressure : Pressure = 20.0;
        doc
        /* The subsystem shall provide water at the public tap stand at or above the minimum useful pressure when storage volume is above reserve. */
    }

    satisfy MoveFluidRequirement by RoundaboutPlayPumpPumpingSubsystem;
    satisfy HumanPoweredOperationRequirement by RoundaboutPlayPumpPumpingSubsystem.roundabout;
    satisfy MinimumFlowRequirement by RoundaboutPlayPumpPumpingSubsystem.pump;
    satisfy SafeSpeedRequirement by RoundaboutPlayPumpPumpingSubsystem.limiter;
    satisfy BoreholeDepthRequirement by RoundaboutPlayPumpPumpingSubsystem.borehole;
    satisfy StorageRequirement by RoundaboutPlayPumpPumpingSubsystem.storageTank;
    satisfy MaintainabilityRequirement by RoundaboutPlayPumpPumpingSubsystem.monitor;
    satisfy PublicOutletRequirement by RoundaboutPlayPumpPumpingSubsystem.tapStand;

    analysis def NominalPumpingPerformanceAnalysis {
        subject subsystem : RoundaboutPlayPumpPumpingSubsystem;

        objective verifyNominalFlow {
            doc
            /* Verify that nominal play rotation produces at least 18 L/min at the storage tank inlet. */
        }

        result nominalFlowSatisfied : Boolean;
    }

    verification def RoundaboutOverspeedVerification {
        subject limiter : SpeedLimiter;

        objective verifySpeedLimit {
            doc
            /* Demonstrate that the speed limiter prevents rotary output above 32 rpm under maximum rider input. */
        }

        result overspeedPrevented : Boolean;
    }

    verification def PumpDeliveryVerification {
        subject subsystem : RoundaboutPlayPumpPumpingSubsystem;

        objective verifyWaterDelivery {
            doc
            /* Demonstrate continuous delivery from groundwater source to public outlet through borehole, pump, pipe, tank, and tap stand. */
        }

        result deliveryVerified : Boolean;
    }
}