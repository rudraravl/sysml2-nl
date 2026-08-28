package FluidInjectionSystem {
    private import ISQ::*;
    private import SI::*;
    private import ScalarValues::*;

    attribute def PressureValue :> ScalarValues::Real;
    attribute def DurationValue :> ScalarValues::Real;
    attribute def FlowRateValue :> ScalarValues::Real;
    attribute def VolumeValue :> ScalarValues::Real;

    item def Fluid;
    item def CommandSignal {
        attribute injectionDuration : DurationValue;
    }
    item def FlowFeedback {
        attribute rate : FlowRateValue;
    }

    part def FluidReservoir {
        out item fluid : Fluid;
        attribute supplyPressure : PressureValue = 300000 [Pa];
    }

    part def PressureRegulator {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
        attribute operatingPressure : PressureValue = 200000 [Pa];
    }

    part def FlowMeter {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
        out item feedback : FlowFeedback;
    }

    part def DeliveryNozzle {
        in item fluidIn : Fluid;
        attribute sprayAngle : ScalarValues::Real = 45;
    }

    part def InjectionController {
        in item feedback : FlowFeedback;
        out item command : CommandSignal;
        attribute targetVolume : VolumeValue = 0.00005;
    }

    part def InjectorValve {
        in item fluidIn : Fluid;
        out item fluidOut : Fluid;
        in item command : CommandSignal;

        state def InjectorValveStates {
            entry; then idle;
            state idle;
            transition idle_to_priming
                first idle
                accept command : CommandSignal
                then priming;
            state priming;
            transition priming_to_injecting
                first priming
                then injecting;
            state injecting;
            transition injecting_to_purging
                first injecting
                then purging;
            state purging;
            transition purging_to_idle
                first purging
                then idle;
        }

        exhibit injectorValveStates : InjectorValveStates;
    }

    part def InjectionSystem {
        part reservoir : FluidReservoir;
        part regulator : PressureRegulator;
        part valve : InjectorValve;
        part meter : FlowMeter;
        part nozzle : DeliveryNozzle;
        part controller : InjectionController;

        connect reservoir.fluid to regulator.fluidIn;
        connect regulator.fluidOut to valve.fluidIn;
        connect valve.fluidOut to meter.fluidIn;
        connect meter.fluidOut to nozzle.fluidIn;

        connect controller.command to valve.command;
        connect meter.feedback to controller.feedback;
    }

    requirement req_precision {
        doc /* The system shall deliver fluid with a volume accuracy of +/- 0.5%. */
    }
    requirement req_responseTime {
        doc /* The injector valve shall respond to open commands within 2 ms. */
    }
    requirement req_pressureLimit {
        doc /* Operating pressure shall not exceed 500 kPa. */
    }
    requirement req_temperatureLimit {
        doc /* Operating temperature shall remain between 273 K and 373 K. */
    }
    requirement req_cycleLife {
        doc /* The system shall withstand at least 10 million injection cycles without failure. */
    }
    requirement req_sprayPattern {
        doc /* The delivery nozzle shall produce a 45-degree cone spray pattern. */
    }

    part injectionSystem : InjectionSystem;

    satisfy req_precision by injectionSystem;
    satisfy req_responseTime by injectionSystem;
    satisfy req_pressureLimit by injectionSystem;
    satisfy req_temperatureLimit by injectionSystem;
    satisfy req_cycleLife by injectionSystem;
    satisfy req_sprayPattern by injectionSystem;
}
