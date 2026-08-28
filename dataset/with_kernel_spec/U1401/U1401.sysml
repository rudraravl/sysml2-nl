package AlJazariWaterClock {
    private import SI::*;
    private import ScalarValues::*;

    attribute def VolumeValue;
    attribute def AngleValue;
    attribute def PressureValue;
    attribute def FlowRateValue;
    attribute def AngularVelocityValue;

    item def Water;
    item def HourlySignal;
    item def Rotation {
        attribute angle : AngleValue;
    }

    port def WaterInPort {
        in item water : Water;
    }
    port def WaterOutPort {
        out item water : Water;
    }
    port def SignalInPort {
        in item signal : HourlySignal;
    }
    port def SignalOutPort {
        out item signal : HourlySignal;
    }
    port def RotationInPort {
        in item rotation : Rotation;
    }
    port def RotationOutPort {
        out item rotation : Rotation;
    }

    part def SupplyReservoir {
        port waterOut : WaterOutPort;
        attribute capacity : VolumeValue;
        attribute pressure : PressureValue;
    }

    part def FloatRegulator {
        port waterIn : WaterInPort;
        port waterOut : WaterOutPort;
        attribute calibratedRate : FlowRateValue;
    }

    part def TimekeepingChamber {
        port waterIn : WaterInPort;
        port signalOut : SignalOutPort;
        port waterOut : WaterOutPort;
        attribute fillVolume : VolumeValue;

        state chamberBehavior {
            entry; then filling;
            state filling;
            accept after 1 [h] then full;
            state full;
            accept after 1 [s] then draining;
            state draining;
            accept after 5 [min] then filling;
        }
    }

    part def GongMechanism {
        port signalIn : SignalInPort;
        state gongBehavior {
            entry; then idle;
            state idle;
            accept signal : HourlySignal via signalIn
                then striking;
            state striking;
            accept after 10 [s]
                then idle;
        }
    }

    part def Automaton {
        port signalIn : SignalInPort;
        state automatonBehavior {
            entry; then idle;
            state idle;
            accept signal : HourlySignal via signalIn
                then performing;
            state performing;
            accept after 30 [s]
                then idle;
        }
    }

    part def SingingBird :> Automaton;
    part def ElephantMahout :> Automaton;

    part def DrumMechanism {
        port waterIn : WaterInPort;
        port rotationOut : RotationOutPort;
        attribute rotationSpeed : AngularVelocityValue;
    }

    part def DialIndicator {
        port rotationIn : RotationInPort;
        attribute displayedHour : ScalarValues::Integer;
    }

    part def WaterClock {
        part supplyReservoir : SupplyReservoir;
        part floatRegulator : FloatRegulator;
        part timekeepingChamber : TimekeepingChamber;
        part gongMechanism : GongMechanism;
        part singingBird : SingingBird;
        part elephantMahout : ElephantMahout;
        part drumMechanism : DrumMechanism;
        part dialIndicator : DialIndicator;

        connect supplyReservoir.waterOut to floatRegulator.waterIn;
        connect floatRegulator.waterOut to timekeepingChamber.waterIn;
        connect timekeepingChamber.signalOut to gongMechanism.signalIn;
        connect timekeepingChamber.signalOut to singingBird.signalIn;
        connect timekeepingChamber.signalOut to elephantMahout.signalIn;
        connect timekeepingChamber.waterOut to drumMechanism.waterIn;
        connect drumMechanism.rotationOut to dialIndicator.rotationIn;
    }

    part waterClock : WaterClock;

    requirement def MeasureTimeRequirement {
        doc /* The system shall measure the passage of time using a controlled flow of water. */
    }

    requirement def DisplayTimeRequirement {
        doc /* The system shall continuously display the current hour via a dial indicator. */
    }

    requirement def AnnounceHourRequirement {
        doc /* The system shall audibly announce each hour using a gong mechanism. */
    }

    requirement def OperateAutonomouslyRequirement {
        doc /* The system shall operate continuously and autonomously, requiring only periodic refilling of the main reservoir. */
    }

    requirement measureTimeReq : MeasureTimeRequirement;
    requirement displayTimeReq : DisplayTimeRequirement;
    requirement announceHourReq : AnnounceHourRequirement;
    requirement operateAutonomouslyReq : OperateAutonomouslyRequirement;

    satisfy measureTimeReq by waterClock;
    satisfy displayTimeReq by waterClock;
    satisfy announceHourReq by waterClock;
    satisfy operateAutonomouslyReq by waterClock;
}
