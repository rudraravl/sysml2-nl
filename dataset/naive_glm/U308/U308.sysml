package MichaabWaterManagement {
    import ScalarValues::*;
    import ISQ::*;

    // ===== Value Types with Units =====
    value def VolumeFlowRate :> Real { unit 'm3/s'; }
    value def WaterLevel :> Real { unit 'm'; }
    value def WaterVolume :> Real { unit 'm3'; }
    value def GatePosition :> Real { unit 'percent'; }
    value def RotationalSpeed :> Real { unit 'rpm'; }
    value def Torque :> Real { unit 'N*m'; }
    value def Turbidity :> Real { unit 'NTU'; }
    value def Temperature :> Real { unit 'degC'; }
    value def GrainMass :> Real { unit 'kg'; }
    value def Pressure :> Real { unit 'Pa'; }

    enumeration GateStatus { closed; partiallyOpen; fullyOpen; }
    enumeration SystemMode { filling; milling; irrigation; idle; maintenance; }
    enumeration WaterQualityGrade { excellent; acceptable; unsuitable; }

    item def Water;
    item def Grain;
    item def Flour;

    // ===== Requirements =====
    requirement def ReservoirCapacityRequirement {
        doc /* The upper reservoir must store sufficient water for milling and irrigation. */
        attribute minCapacity : WaterVolume = 500 [m3];
        attribute maxCapacity : WaterVolume = 5000 [m3];
        constraint { minCapacity <= maxCapacity }
    }

    requirement def FlowControlRequirement {
        doc /* The main control gate must regulate flow from fully closed to fully open. */
        attribute maxFlowRate : VolumeFlowRate = 2.0 [m3/s];
        constraint { maxFlowRate > 0 [m3/s] }
    }

    requirement def IrrigationQualityRequirement {
        doc /* Irrigation water must meet quality standards for crops. */
        attribute maxTurbidity : Turbidity = 50 [NTU];
        constraint { maxTurbidity > 0 [NTU] }
    }

    requirement def MillingPowerRequirement {
        doc /* The water wheel must generate sufficient torque to drive the millstones. */
        attribute minTorque : Torque = 500 [N*m];
        attribute minSpeed : RotationalSpeed = 20 [rpm];
        constraint { minTorque > 0 [N*m] and minSpeed > 0 [rpm] }
    }

    requirement MichaabSystemRequirements {
        subject michaab : Michaab;
        satisfy ReservoirCapacityRequirement;
        satisfy FlowControlRequirement;
        satisfy IrrigationQualityRequirement;
        satisfy MillingPowerRequirement;
    }

    // ===== Port Definitions =====
    port def WaterInPort { in item water : Water; }
    port def WaterOutPort { out item water : Water; }
    port def ControlSignalPort { in attribute command : GatePosition; }
    port def FeedbackPort { out attribute level : WaterLevel; out attribute turbidity : Turbidity; }
    port def MechanicalPowerPort { out attribute speed : RotationalSpeed; out attribute torque : Torque; }
    port def GrainInPort { in item grain : Grain; }
    port def FlourOutPort { out item flour : Flour; }

    // ===== Part Definitions =====
    part def UpperReservoir {
        attribute capacity : WaterVolume = 5000 [m3];
        attribute currentLevel : WaterLevel = 0 [m];
        attribute maxLevel : WaterLevel = 4 [m];
        attribute minOperationalLevel : WaterLevel = 0.5 [m];
        port waterOut : WaterOutPort;
        port feedback : FeedbackPort;
        port inflow : WaterInPort;

        action def FillReservoir {
            in incomingWater : Water;
            update currentLevel;
        }

        action def MonitorLevel {
            out measuredLevel : WaterLevel = currentLevel;
        }

        perform MonitorLevel continuously;
    }

    part def DistributionChannel {
        attribute channelLength : Real = 50 [m];
        attribute channelWidth : Real = 1.2 [m];
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def MainControlGate {
        attribute position : GatePosition = 0 [percent];
        attribute status : GateStatus = GateStatus::closed;
        attribute maxFlowRate : VolumeFlowRate = 2.0 [m3/s];
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port waterDivert : WaterOutPort;
        port control : ControlSignalPort;

        action def AdjustGate {
            in targetPosition : GatePosition;
            update position;
            decide {
                if position == 0 [percent] then { status = GateStatus::closed; }
                if position >= 95 [percent] then { status = GateStatus::fullyOpen; }
                else { status = GateStatus::partiallyOpen; }
            }
        }

        action def RegulateFlow {
            in incomingFlow : VolumeFlowRate;
            out outgoingFlow : VolumeFlowRate = incomingFlow * (position / 100);
            out divertedFlow : VolumeFlowRate = incomingFlow * (position / 100) * 0.3;
        }

        perform AdjustGate when control.command != position;
    }

    part def SecondaryChannel {
        attribute length : Real = 15 [m];
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
    }

    part def WaterWheel {
        attribute diameter : Real = 4 [m];
        attribute width : Real = 1.5 [m];
        attribute currentSpeed : RotationalSpeed = 0 [rpm];
        attribute currentTorque : Torque = 0 [N*m];
        attribute efficiency : Real = 0.75;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port mechanicalOut : MechanicalPowerPort;

        action def Rotate {
            in flowRate : VolumeFlowRate;
            update currentSpeed;
            update currentTorque;
        }

        perform Rotate continuously;
    }

    part def MillingMechanism {
        attribute upperStoneDiameter : Real = 1.5 [m];
        attribute lowerStoneDiameter : Real = 1.5 [m];
        attribute upperStoneMass : GrainMass = 300 [kg];
        attribute grindingRate : Real = 50 [kg/h];
        attribute isOperating : Boolean = false;
        port mechanicalIn : MechanicalPowerPort;
        port grainIn : GrainInPort;
        port flourOut : FlourOutPort;

        action def GrindGrain {
            in grain : Grain;
            in speed : RotationalSpeed;
            in torque : Torque;
            out flour : Flour;
            update isOperating = (speed > 0 [rpm] and torque > 0 [N*m]);
        }

        perform GrindGrain when mechanicalIn.speed > 0 [rpm];
    }

    part def LowerReservoir {
        attribute capacity : WaterVolume = 2000 [m3];
        attribute currentLevel : WaterLevel = 0 [m];
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;

        action def CollectWater {
            in water : Water;
            update currentLevel;
        }

        perform CollectWater continuously;
    }

    part def IrrigationOutlet {
        attribute dedicatedGatePosition : GatePosition = 0 [percent];
        attribute maxFlowRate : VolumeFlowRate = 0.5 [m3/s];
        attribute isRestricted : Boolean = false;
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        port control : ControlSignalPort;

        action def DeliverWater {
            in flowRate : VolumeFlowRate;
            in quality : WaterQualityGrade;
            decide {
                if quality == WaterQualityGrade::unsuitable then {
                    dedicatedGatePosition = 0 [percent];
                    isRestricted = true;
                }
                else {
                    isRestricted = false;
                }
            }
        }

        perform DeliverWater continuously;
    }

    part def WaterQualitySensor {
        attribute turbidityReading : Turbidity = 0 [NTU];
        attribute temperatureReading : Temperature = 20 [degC];
        attribute qualityGrade : WaterQualityGrade = WaterQualityGrade::excellent;
        port waterSample : WaterInPort;
        port feedback : FeedbackPort;

        action def AssessQuality {
            in turbidity : Turbidity;
            decide {
                if turbidity <= 20 [NTU] then { qualityGrade = WaterQualityGrade::excellent; }
                if turbidity > 20 [NTU] and turbidity <= 50 [NTU] then { qualityGrade = WaterQualityGrade::acceptable; }
                if turbidity > 50 [NTU] then { qualityGrade = WaterQualityGrade::unsuitable; }
            }
        }

        perform AssessQuality continuously;
    }

    part def ControlSystem {
        attribute currentMode : SystemMode = SystemMode::idle;
        attribute targetLevel : WaterLevel = 3.5 [m];
        attribute targetGatePosition : GatePosition = 50 [percent];
        attribute irrigationGatePosition : GatePosition = 50 [percent];
        port reservoirFeedback : FeedbackPort;
        port qualityFeedback : FeedbackPort;
        port mainGateControl : ControlSignalPort;
        port irrigationGateControl : ControlSignalPort;

        action def MonitorSystem {
            in reservoirLevel : WaterLevel;
            in waterTurbidity : Turbidity;
            update currentMode;
        }

        action def AdjustMainGate {
            in level : WaterLevel;
            decide {
                if level < 1.0 [m] then { targetGatePosition = 10 [percent]; currentMode = SystemMode::filling; }
                if level >= 1.0 [m] and level < 3.0 [m] then { targetGatePosition = 60 [percent]; currentMode = SystemMode::milling; }
                if level >= 3.0 [m] then { targetGatePosition = 85 [percent]; currentMode = SystemMode::irrigation; }
            }
        }

        action def AdjustIrrigationGate {
            in quality : WaterQualityGrade;
            decide {
                if quality == WaterQualityGrade::unsuitable then { irrigationGatePosition = 0 [percent]; }
                if quality == WaterQualityGrade::acceptable then { irrigationGatePosition = 30 [percent]; }
                if quality == WaterQualityGrade::excellent then { irrigationGatePosition = 70 [percent]; }
            }
        }

        state def ControlStateMachine {
            entry; then Filling;
            state Filling;
            transition from Filling to Milling when reservoirFeedback.level >= 1.0 [m];
            state Milling;
            transition from Milling to Irrigating when reservoirFeedback.level >= 3.0 [m];
            state Irrigating;
            transition from Irrigating to Idle when reservoirFeedback.level < 0.5 [m];
            state Idle;
            transition from Idle to Maintenance when controlSystemCommand == 'maintenance';
            state Maintenance;
            transition from Maintenance to Filling when controlSystemCommand == 'resume';
        }

        perform MonitorSystem continuously;
        perform AdjustMainGate when reservoirFeedback.level != targetLevel;
        perform AdjustIrrigationGate when qualityFeedback.turbidity > 0 [NTU];
        exhibit ControlStateMachine;
    }

    // ===== Top-Level Michaab System =====
    part def Michaab {
        attribute systemName : String = "Michaab Water Management System";
        attribute operationalMode : SystemMode = SystemMode::idle;
        satisfy MichaabSystemRequirements;

        part upperReservoir : UpperReservoir {
            attribute capacity = 5000 [m3];
        }
        part distributionChannel : DistributionChannel;
        part mainControlGate : MainControlGate;
        part secondaryChannel : SecondaryChannel;
        part waterWheel : WaterWheel;
        part millingMechanism : MillingMechanism;
        part lowerReservoir : LowerReservoir;
        part irrigationOutlet : IrrigationOutlet;
        part waterQualitySensor : WaterQualitySensor;
        part controlSystem : ControlSystem;

        // Connections
        connect upperReservoir.waterOut to distributionChannel.waterIn;
        connect distributionChannel.waterOut to mainControlGate.waterIn;
        connect mainControlGate.waterOut to secondaryChannel.waterIn;
        connect mainControlGate.waterDivert to irrigationOutlet.waterIn;
        connect secondaryChannel.waterOut to waterWheel.waterIn;
        connect waterWheel.waterOut to lowerReservoir.waterIn;
        connect waterWheel.mechanicalOut to millingMechanism.mechanicalIn;
        connect upperReservoir.feedback to controlSystem.reservoirFeedback;
        connect waterQualitySensor.feedback to controlSystem.qualityFeedback;
        connect controlSystem.mainGateControl to mainControlGate.control;
        connect controlSystem.irrigationGateControl to irrigationOutlet.control;
        connect upperReservoir.waterOut to waterQualitySensor.waterSample;

        // System-level state machine
        state def SystemOperationStateMachine {
            entry; then Idle;
            state Idle {
                entry { operationalMode = SystemMode::idle; }
            }
            transition from Idle to Filling when upperReservoir.currentLevel < upperReservoir.minOperationalLevel;
            state Filling {
                entry { operationalMode = SystemMode::filling; }
            }
            transition from Filling to Milling when upperReservoir.currentLevel >= 1.0 [m];
            state Milling {
                entry { operationalMode = SystemMode::milling; }
            }
            transition from Milling to Irrigating when upperReservoir.currentLevel >= 3.0 [m] and waterQualitySensor.qualityGrade != WaterQualityGrade::unsuitable;
            state Irrigating {
                entry { operationalMode = SystemMode::irrigation; }
            }
            transition from Irrigating to Milling when upperReservoir.currentLevel < 3.0 [m];
            transition from Milling to Idle when upperReservoir.currentLevel < 0.5 [m];
            transition from any to Maintenance when maintenanceRequested == true;
            state Maintenance {
                entry { operationalMode = SystemMode::maintenance; }
            }
            transition from Maintenance to Idle when maintenanceRequested == false;
        }

        exhibit SystemOperationStateMachine;
    }
}
