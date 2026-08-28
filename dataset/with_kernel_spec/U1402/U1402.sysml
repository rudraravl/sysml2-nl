package DrillingMudCirculationSystem {
    private import ScalarValues::*;
    private import ISQ::*;

    attribute def MudDensity :> Real;
    attribute def MudViscosity :> Real;
    attribute def MudPH :> Real;
    attribute def MudTemperature :> Real;
    attribute def MudPressure :> Real;
    attribute def MudFlowRate :> Real;

    attribute def StartSignal;
    attribute def StopSignal;
    attribute def ReadySignal;

    item def DrillingMud {
        attribute density : MudDensity;
        attribute viscosity : MudViscosity;
        attribute ph : MudPH;
        attribute temperature : MudTemperature;
        attribute pressure : MudPressure;
    }
    item def Cuttings;
    item def MudMixture {
        item mud : DrillingMud;
        item cuttings : Cuttings;
    }

    port def MudInPort {
        in item mud : DrillingMud;
    }
    port def MudOutPort {
        out item mud : DrillingMud;
    }
    port def MixtureInPort {
        in item mixture : MudMixture;
    }
    port def MixtureOutPort {
        out item mixture : MudMixture;
    }
    port def CuttingsOutPort {
        out item cuttings : Cuttings;
    }

    action def PumpMud {
        in mud : DrillingMud;
        out pumpedMud : DrillingMud;
    }
    action def CoolAndLubricate {
        in mud : DrillingMud;
        out mixture : MudMixture;
    }
    action def SeparateCuttings {
        in mixture : MudMixture;
        out mud : DrillingMud;
        out cuttings : Cuttings;
    }
    action def ConditionMud {
        in mud : DrillingMud;
        out conditionedMud : DrillingMud;
    }
    action def MonitorMud {
        in mud : DrillingMud;
        out density : MudDensity;
        out viscosity : MudViscosity;
        out ph : MudPH;
        out temperature : MudTemperature;
    }
    action def NormalCirculationActivities {
        action 'pump mud' : PumpMud;
        action 'cool and lubricate' : CoolAndLubricate;
        action 'separate cuttings' : SeparateCuttings;
        action 'condition mud' : ConditionMud;
        action 'monitor mud' : MonitorMud;
    }

    part def MudPits {
        port mudOut : MudOutPort;
        port mudIn : MudInPort;
    }
    part def MudPump {
        port mudIn : MudInPort;
        port mudOut : MudOutPort;
    }
    part def DrillString {
        port mudIn : MudInPort;
        port mudOut : MudOutPort;
    }
    part def DrillBit {
        port mudIn : MudInPort;
        port mixtureOut : MixtureOutPort;
    }
    part def Annulus {
        port mixtureIn : MixtureInPort;
        port mixtureOut : MixtureOutPort;
    }
    part def ShakerScreen {
        port mixtureIn : MixtureInPort;
        port mudOut : MudOutPort;
        port cuttingsOut : CuttingsOutPort;
    }
    part def MudConditioner {
        port mudIn : MudInPort;
        port mudOut : MudOutPort;
    }
    part def MudSensors {
        port mudIn : MudInPort;
    }

    part def DrillingMudSystem {
        part mudPits : MudPits;
        part mudPump : MudPump;
        part drillString : DrillString;
        part drillBit : DrillBit;
        part annulus : Annulus;
        part shakerScreen : ShakerScreen;
        part mudConditioner : MudConditioner;
        part mudSensors : MudSensors;

        connect mudPits.mudOut to mudPump.mudIn;
        connect mudPump.mudOut to drillString.mudIn;
        connect drillString.mudOut to drillBit.mudIn;
        connect drillBit.mixtureOut to annulus.mixtureIn;
        connect annulus.mixtureOut to shakerScreen.mixtureIn;
        connect shakerScreen.mudOut to mudConditioner.mudIn;
        connect mudConditioner.mudOut to mudPits.mudIn;
        connect mudConditioner.mudOut to mudSensors.mudIn;

        exhibit state circulationStates {
            entry; then idle;
            state idle;
            accept StartSignal then startup;
            state startup;
            accept ReadySignal then normalCirculation;
            state normalCirculation {
                do 'normal circulation activities' : NormalCirculationActivities;
            }
            accept StopSignal then shutdown;
            state shutdown;
            then idle;
        }
    }

    requirement def MudDensityRequirement {
        doc /* The mud density shall be maintained between 1000 and 2500 kg/m³. */
        subject system : DrillingMudSystem;
        attribute currentDensity : MudDensity;
        require constraint { currentDensity >= 1000.0 and currentDensity <= 2500.0 }
    }
    requirement def FlowRateRequirement {
        doc /* The system shall maintain a minimum circulation flow rate of 0.05 m³/s. */
        subject system : DrillingMudSystem;
        attribute flowRate : MudFlowRate;
        require constraint { flowRate >= 0.05 }
    }
    requirement def CuttingsRemovalRequirement {
        doc /* The shaker screen shall remove at least 95% of solid cuttings from the returning mud. */
        subject system : DrillingMudSystem;
        attribute removalEfficiency : Real;
        require constraint { removalEfficiency >= 0.95 }
    }
    requirement def TemperatureLimitRequirement {
        doc /* The mud temperature at the bit shall not exceed 150 °C to prevent equipment damage. */
        subject system : DrillingMudSystem;
        attribute bitTemp : MudTemperature;
        require constraint { bitTemp <= 150.0 }
    }
}
