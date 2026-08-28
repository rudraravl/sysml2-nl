package IVTherapySystem {

    import ScalarValues::*;

    // ============================================================
    // Value Types with Units
    // ============================================================
    value type Volume :> Real { unit 'mL'; }
    value type FlowRate :> Real { unit 'mL/h'; }
    value type Pressure :> Real { unit 'mmHg'; }
    value type Duration :> Real { unit 'h'; }
    value type Length :> Real { unit 'mm'; }
    value type Temperature :> Real { unit 'degC'; }

    attribute def Percent :> Real {
        constraint { 0 <= self & self <= 100; }
    }

    // ============================================================
    // Item Definitions
    // ============================================================
    item def Saline;
    item def Medication {
        attribute concentration: Real;
        attribute name: String;
    }
    item def Blood;
    item def BloodSample :> Blood {
        attribute volume: Volume;
        attribute sampleId: String;
    }
    item def FlushSolution :> Saline;
    item def InfusionFluid :> Saline | Medication;

    // ============================================================
    // Port Definitions
    // ============================================================
    port def FluidPort {
        in item fluid: Saline | Medication | Blood | BloodSample;
        out item returnFluid: Blood | Saline;
    }

    port def SignalPort {
        in attribute pressureReading: Pressure;
        out attribute flowCommand: FlowRate;
        out attribute alarmTrigger: Boolean;
        out attribute occlusionDetected: Boolean;
    }

    port def ElectricalPort {
        in attribute powerAvailable: Boolean;
        in attribute batteryLevel: Percent;
    }

    // ============================================================
    // Component Part Definitions
    // ============================================================
    part def VenousCatheter {
        attribute material: String = "polyurethane";
        attribute length: Length = 50;
        attribute gauge: Integer = 18;
        attribute biocompatible: Boolean = true;
        attribute sterile: Boolean = true;
        attribute inserted: Boolean = false;
        port distalEnd : FluidPort;
        port proximalEnd : FluidPort;
    }

    part def SafetyNeedle {
        attribute material: String = "stainless steel";
        attribute deployed: Boolean = false;
        attribute retracted: Boolean = false;
        attribute safetyEngaged: Boolean = false;
        port needleTip : FluidPort;

        action engageSafety {
            assign retracted = true;
            assign safetyEngaged = true;
            assign deployed = false;
        }
    }

    part def Hub {
        attribute needlelessPorts: Integer = 2;
        attribute connected: Boolean = false;
        port accessPort1 : FluidPort;
        port accessPort2 : FluidPort;
        port catheterPort : FluidPort;
    }

    part def InfusionBag {
        attribute contents: InfusionFluid;
        attribute remainingVolume: Volume;
        port outlet : FluidPort;
    }

    part def InfusionPump {
        attribute batteryPowered: Boolean = true;
        attribute programmedRate: FlowRate = 0;
        attribute totalVolumeDelivered: Volume = 0;
        attribute targetVolume: Volume = 0;
        attribute alarmActive: Boolean = false;
        attribute running: Boolean = false;
        port powerPort : ElectricalPort;
        port controlPort : SignalPort;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;

        action def ProgramInfusion(in rate: FlowRate, in volume: Volume) {
            assign programmedRate = rate;
            assign targetVolume = volume;
            assign totalVolumeDelivered = 0;
        }

        action def StartPump { assign running = true; }
        action def StopPump {
            assign running = false;
            assign programmedRate = 0;
        }
        action def TriggerAlarm { assign alarmActive = true; }
        action def ClearAlarm { assign alarmActive = false; }

        state def PumpOperation {
            entry; then idle;
            state idle {
                entry { assign running = false; }
            }
            state infusing {
                entry { assign running = true; }
            }
            state occluded {
                entry { assign alarmActive = true; }
                do StopPump;
            }
            state completed {
                entry { assign running = false; }
            }
            transition idle -> infusing
                when programmedRate > 0 & targetVolume > 0;
            transition infusing -> occluded
                when controlPort.pressureReading > 300[Pressure];
            transition infusing -> completed
                when totalVolumeDelivered >= targetVolume;
            transition completed -> idle
                when alarmActive == false;
            transition occluded -> idle
                when alarmActive == false;
        }
    }

    part def FlowRegulator {
        attribute setRate: FlowRate = 0;
        attribute regulating: Boolean = false;
        port fluidIn : FluidPort;
        port fluidOut : FluidPort;
        port controlPort : SignalPort;

        action regulateFlow {
            // maintain output flow at setRate
        }
    }

    part def PressureSensor {
        attribute currentPressure: Pressure = 0;
        attribute threshold: Pressure = 300;
        attribute occlusionDetected: Boolean = false;
        port fluidPort : FluidPort;
        port signalPort : SignalPort;

        action measurePressure {
            // sample line pressure and emit reading
        }
        action checkOcclusion {
            assign occlusionDetected = currentPressure > threshold;
        }
    }

    part def Patient {
        attribute veinLocation: String = "antecubital";
        attribute veinAccessed: Boolean = false;
        port veinAccess : FluidPort;
    }

    // ============================================================
    // Top-Level IV Therapy System
    // ============================================================
    part def IVTherapySystem {
        attribute systemId: String;
        attribute sterilePackaged: Boolean = true;
        attribute deployed: Boolean = false;
        attribute disposed: Boolean = false;

        part catheter : VenousCatheter;
        part needle : SafetyNeedle;
        part hub : Hub;
        part pump : InfusionPump;
        part regulator : FlowRegulator;
        part sensor : PressureSensor;
        part bag : InfusionBag;
        part patient : Patient;

        // Fluid path connections
        connect bag.outlet to pump.fluidIn;
        connect pump.fluidOut to regulator.fluidIn;
        connect regulator.fluidOut to hub.accessPort1;
        connect hub.catheterPort to catheter.proximalEnd;
        connect catheter.distalEnd to patient.veinAccess;
        connect needle.needleTip to catheter.distalEnd;

        // Signal and power connections
        connect sensor.fluidPort to regulator.fluidOut;
        connect sensor.signalPort to pump.controlPort;
        connect pump.controlPort to regulator.controlPort;

        // Item flows
        flow of InfusionFluid from bag.outlet to pump.fluidIn;
        flow of InfusionFluid from pump.fluidOut to regulator.fluidIn;
        flow of InfusionFluid from regulator.fluidOut to hub.accessPort1;
        flow of InfusionFluid from hub.catheterPort to catheter.proximalEnd;
        flow of InfusionFluid from catheter.distalEnd to patient.veinAccess;
        flow of Blood from patient.veinAccess to catheter.distalEnd;

        // ============================================================
        // System Lifecycle State Machine
        // ============================================================
        state def SystemLifecycle {
            entry; then packaged;
            state packaged {
                entry { assign sterilePackaged = true; }
            }
            state veinLocated {
                entry { assign patient.veinAccessed = true; }
            }
            state inserting {
                entry { assign needle.deployed = true; }
            }
            state bloodReturnConfirmed;
            state catheterAdvanced {
                entry { assign catheter.inserted = true; }
            }
            state needleWithdrawn {
                entry { needle.engageSafety; }
            }
            state deployedState {
                entry { assign deployed = true; }
            }
            state removed {
                entry { assign catheter.inserted = false; }
            }
            state discarded {
                entry { assign disposed = true; }
            }

            transition packaged -> veinLocated
                when patient.veinAccessed == true;
            transition veinLocated -> inserting;
            transition inserting -> bloodReturnConfirmed
                when catheter.distalEnd.returnFluid != null;
            transition bloodReturnConfirmed -> catheterAdvanced;
            transition catheterAdvanced -> needleWithdrawn;
            transition needleWithdrawn -> deployedState
                when needle.safetyEngaged == true;
            transition deployedState -> removed;
            transition removed -> discarded;
        }

        // ============================================================
        // Infusion Administration Behavior
        // ============================================================
        action def AdministerInfusion(in rate: FlowRate, in volume: Volume) {
            first program;
            action program : pump.ProgramInfusion(rate, volume);
            then start;
            action start : pump.StartPump;
            then monitor;
            action monitor {
                // continuously observe sensor.currentPressure
                // and pump.totalVolumeDelivered
            }
            then check;
            decision check;
            if pump.alarmActive == true then stop;
            if pump.totalVolumeDelivered >= volume then finish;
            else monitor;
            action stop : pump.StopPump;
            action finish : pump.StopPump;
        }

        // ============================================================
        // Blood Sample Draw Behavior
        // ============================================================
        action def DrawBloodSample(in requiredVolume: Volume) {
            first discard;
            action discard {
                // discard initial volume to clear line
            }
            then collect;
            action collect {
                // collect BloodSample of requiredVolume via hub.accessPort2
            }
            then flush;
            action flush {
                // flush catheter with saline
            }
        }

        // ============================================================
        // Patency Maintenance Behavior
        // ============================================================
        action def MaintainPatency {
            attribute flushInterval: Duration = 8;
            first flushCatheter;
            action flushCatheter {
                // flush with saline to prevent clotting
            }
            then wait;
            action wait {
                // wait flushInterval hours
            }
            then flushCatheter;
        }
    }

    // ============================================================
    // Requirements
    // ============================================================
    requirement def BiocompatibilityRequirement {
        doc /* All materials contacting the patient must be biocompatible. */
        subject catheterPart : VenousCatheter;
        require { catheterPart.biocompatible == true; }
    }

    requirement def SterilityRequirement {
        doc /* The disposable device must be sterile prior to insertion. */
        subject device : IVTherapySystem;
        require { device.sterilePackaged == true; }
    }

    requirement def FlowControlRequirement {
        doc /* The infusion pump shall deliver fluid at a controlled rate. */
        subject pump : InfusionPump;
        require { pump.programmedRate >= 0[FlowRate]; }
    }

    requirement def PressureMonitoringRequirement {
        doc /* Line pressure shall be continuously monitored and occlusion shall stop the pump. */
        subject sensor : PressureSensor;
        subject pump : InfusionPump;
        require { sensor.occlusionDetected == true implies pump.running == false; }
    }

    requirement def OcclusionAlarmRequirement {
        doc /* An occlusion shall trigger an alarm. */
        subject pump : InfusionPump;
        require { sensor.occlusionDetected == true implies pump.alarmActive == true; }
    }

    requirement def NeedleSafetyRequirement {
        doc /* The safety needle shall retract after use to prevent needlesticks. */
        subject needle : SafetyNeedle;
        require { needle.safetyEngaged == true implies needle.retracted == true; }
    }

    requirement def PatencyMaintenanceRequirement {
        doc /* The catheter shall be flushed with saline every 8 hours when not in active use. */
        subject system : IVTherapySystem;
        require { system.MaintainPatency.flushInterval == 8[Duration]; }
    }

    requirement def VolumeTrackingRequirement {
        doc /* The pump shall track total volume delivered. */
        subject pump : InfusionPump;
        require { pump.totalVolumeDelivered >= 0[Volume]; }
    }

    requirement def DisposalRequirement {
        doc /* After removal, the disposable assembly shall be safely discarded. */
        subject device : IVTherapySystem;
        require { device.disposed == true; }
    }

    // ============================================================
    // Requirement Satisfaction
    // ============================================================
    satisfaction biocompatibilitySatisfies : BiocompatibilityRequirement {
        subject catheterPart :> catheter;
    }
    satisfaction sterilitySatisfies : SterilityRequirement {
        subject device :> IVTherapySystem;
    }
    satisfaction flowControlSatisfies : FlowControlRequirement {
        subject pump :> pump;
    }
    satisfaction pressureMonitoringSatisfies : PressureMonitoringRequirement {
        subject sensor :> sensor;
        subject pump :> pump;
    }
    satisfaction occlusionAlarmSatisfies : OcclusionAlarmRequirement {
        subject pump :> pump;
    }
    satisfaction needleSafetySatisfies : NeedleSafetyRequirement {
        subject needle :> needle;
    }
    satisfaction patencySatisfies : PatencyMaintenanceRequirement {
        subject system :> IVTherapySystem;
    }
    satisfaction volumeTrackingSatisfies : VolumeTrackingRequirement {
        subject pump :> pump;
    }
    satisfaction disposalSatisfies : DisposalRequirement {
        subject device :> IVTherapySystem;
    }
}
