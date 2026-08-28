package 'Electronic Fuel Injection System' {
    private import ScalarValues::*;

    item def Fuel;
    item def Air;
    item def AirFuelMixture;
    item def ExhaustGas;

    item def FuelCommand {
        attribute pulseWidth : Real;
    }
    item def MassAirFlowSignal {
        attribute massFlowRate : Real;
    }
    item def ThrottlePositionSignal {
        attribute throttleAngle : Real;
    }
    item def EngineSpeedSignal {
        attribute rpm : Real;
    }
    item def OxygenSignal {
        attribute lambda : Real;
    }

    part def FuelTank {
        port fuelSupplyPort {
            out item fuel : Fuel;
        }
        port fuelReturnPort {
            in item fuel : Fuel;
        }
    }
    part def FuelPump {
        port fuelInPort {
            in item fuel : Fuel;
        }
        port highPressureFuelPort {
            out item fuel : Fuel;
        }
    }
    part def FuelFilter {
        port fuelInPort {
            in item fuel : Fuel;
        }
        port fuelOutPort {
            out item fuel : Fuel;
        }
    }
    part def PressureRegulator {
        port fuelInPort {
            in item fuel : Fuel;
        }
        port regulatedFuelPort {
            out item fuel : Fuel;
        }
        port returnFuelPort {
            out item fuel : Fuel;
        }
    }
    part def FuelRail {
        port fuelInPort {
            in item fuel : Fuel;
        }
        port injector1Port {
            out item fuel : Fuel;
        }
        port injector2Port {
            out item fuel : Fuel;
        }
        port injector3Port {
            out item fuel : Fuel;
        }
        port injector4Port {
            out item fuel : Fuel;
        }
    }
    part def FuelInjector {
        port fuelInPort {
            in item fuel : Fuel;
        }
        port commandInPort {
            in item command : FuelCommand;
        }
        port sprayOutPort {
            out item fuel : Fuel;
        }
    }
    part def ThrottleBody {
        port airInPort {
            in item air : Air;
        }
        port airOutPort {
            out item air : Air;
        }
    }
    part def IntakeManifold {
        port airInPort {
            in item air : Air;
        }
        port fuelIn1Port {
            in item fuel : Fuel;
        }
        port fuelIn2Port {
            in item fuel : Fuel;
        }
        port fuelIn3Port {
            in item fuel : Fuel;
        }
        port fuelIn4Port {
            in item fuel : Fuel;
        }
        port mixtureOutPort {
            out item mixture : AirFuelMixture;
        }
    }
    part def MassAirFlowSensor {
        port airInPort {
            in item air : Air;
        }
        port airOutPort {
            out item air : Air;
        }
        port signalOutPort {
            out item signal : MassAirFlowSignal;
        }
    }
    part def ThrottlePositionSensor {
        port signalOutPort {
            out item signal : ThrottlePositionSignal;
        }
    }
    part def CrankshaftPositionSensor {
        port signalOutPort {
            out item signal : EngineSpeedSignal;
        }
    }
    part def OxygenSensor {
        port exhaustInPort {
            in item exhaust : ExhaustGas;
        }
        port signalOutPort {
            out item signal : OxygenSignal;
        }
    }
    part def Engine {
        port mixtureInPort {
            in item mixture : AirFuelMixture;
        }
        port exhaustOutPort {
            out item exhaust : ExhaustGas;
        }
    }
    part def AirSource {
        port airOutPort {
            out item air : Air;
        }
    }

    action def ECUControlLoop {
        in mafSignal : MassAirFlowSignal;
        in tpsSignal : ThrottlePositionSignal;
        in rpmSignal : EngineSpeedSignal;
        in o2Signal : OxygenSignal;
        out cmd1 : FuelCommand;
        out cmd2 : FuelCommand;
        out cmd3 : FuelCommand;
        out cmd4 : FuelCommand;

        action readSensors {
            in maf : MassAirFlowSignal = mafSignal;
            in tps : ThrottlePositionSignal = tpsSignal;
            in rpm : EngineSpeedSignal = rpmSignal;
            in o2 : OxygenSignal = o2Signal;
        }
        then action calculateFuel {
            in maf : MassAirFlowSignal = readSensors.maf;
            in tps : ThrottlePositionSignal = readSensors.tps;
            in rpm : EngineSpeedSignal = readSensors.rpm;
            in o2 : OxygenSignal = readSensors.o2;
            out pulseWidth : Real;
        }
        then action sendCommands {
            in pw : Real = calculateFuel.pulseWidth;
            out c1 : FuelCommand = cmd1;
            out c2 : FuelCommand = cmd2;
            out c3 : FuelCommand = cmd3;
            out c4 : FuelCommand = cmd4;
        }
    }

    part def ECU {
        port mafInPort {
            in item signal : MassAirFlowSignal;
        }
        port tpsInPort {
            in item signal : ThrottlePositionSignal;
        }
        port rpmInPort {
            in item signal : EngineSpeedSignal;
        }
        port o2InPort {
            in item signal : OxygenSignal;
        }
        port injector1CommandPort {
            out item command : FuelCommand;
        }
        port injector2CommandPort {
            out item command : FuelCommand;
        }
        port injector3CommandPort {
            out item command : FuelCommand;
        }
        port injector4CommandPort {
            out item command : FuelCommand;
        }

        action controlLoop : ECUControlLoop {
            in mafSignal = mafInPort.signal;
            in tpsSignal = tpsInPort.signal;
            in rpmSignal = rpmInPort.signal;
            in o2Signal = o2InPort.signal;
            out cmd1 = injector1CommandPort.command;
            out cmd2 = injector2CommandPort.command;
            out cmd3 = injector3CommandPort.command;
            out cmd4 = injector4CommandPort.command;
        }
    }

    part def EFISystem {
        part tank : FuelTank;
        part fuelPump : FuelPump;
        part fuelFilter : FuelFilter;
        part regulator : PressureRegulator;
        part rail : FuelRail;
        part injector1 : FuelInjector;
        part injector2 : FuelInjector;
        part injector3 : FuelInjector;
        part injector4 : FuelInjector;
        part throttleBody : ThrottleBody;
        part intakeManifold : IntakeManifold;
        part mafSensor : MassAirFlowSensor;
        part tpsSensor : ThrottlePositionSensor;
        part ckpSensor : CrankshaftPositionSensor;
        part o2Sensor : OxygenSensor;
        part engine : Engine;
        part airSource : AirSource;
        part ecu : ECU;

        flow tankToPump of Fuel from tank.fuelSupplyPort.fuel to fuelPump.fuelInPort.fuel;
        flow pumpToFilter of Fuel from fuelPump.highPressureFuelPort.fuel to fuelFilter.fuelInPort.fuel;
        flow filterToRegulator of Fuel from fuelFilter.fuelOutPort.fuel to regulator.fuelInPort.fuel;
        flow regulatorToRail of Fuel from regulator.regulatedFuelPort.fuel to rail.fuelInPort.fuel;
        flow railToInjector1 of Fuel from rail.injector1Port.fuel to injector1.fuelInPort.fuel;
        flow railToInjector2 of Fuel from rail.injector2Port.fuel to injector2.fuelInPort.fuel;
        flow railToInjector3 of Fuel from rail.injector3Port.fuel to injector3.fuelInPort.fuel;
        flow railToInjector4 of Fuel from rail.injector4Port.fuel to injector4.fuelInPort.fuel;
        flow returnToTank of Fuel from regulator.returnFuelPort.fuel to tank.fuelReturnPort.fuel;

        flow airSourceToMaf of Air from airSource.airOutPort.air to mafSensor.airInPort.air;
        flow mafToThrottle of Air from mafSensor.airOutPort.air to throttleBody.airInPort.air;
        flow throttleToManifold of Air from throttleBody.airOutPort.air to intakeManifold.airInPort.air;

        flow injector1ToManifold of Fuel from injector1.sprayOutPort.fuel to intakeManifold.fuelIn1Port.fuel;
        flow injector2ToManifold of Fuel from injector2.sprayOutPort.fuel to intakeManifold.fuelIn2Port.fuel;
        flow injector3ToManifold of Fuel from injector3.sprayOutPort.fuel to intakeManifold.fuelIn3Port.fuel;
        flow injector4ToManifold of Fuel from injector4.sprayOutPort.fuel to intakeManifold.fuelIn4Port.fuel;

        flow mixtureToEngine of AirFuelMixture from intakeManifold.mixtureOutPort.mixture to engine.mixtureInPort.mixture;
        flow exhaustToO2 of ExhaustGas from engine.exhaustOutPort.exhaust to o2Sensor.exhaustInPort.exhaust;

        flow mafSignalToECU of MassAirFlowSignal from mafSensor.signalOutPort.signal to ecu.mafInPort.signal;
        flow tpsSignalToECU of ThrottlePositionSignal from tpsSensor.signalOutPort.signal to ecu.tpsInPort.signal;
        flow rpmSignalToECU of EngineSpeedSignal from ckpSensor.signalOutPort.signal to ecu.rpmInPort.signal;
        flow o2SignalToECU of OxygenSignal from o2Sensor.signalOutPort.signal to ecu.o2InPort.signal;

        flow ecuToInjector1 of FuelCommand from ecu.injector1CommandPort.command to injector1.commandInPort.command;
        flow ecuToInjector2 of FuelCommand from ecu.injector2CommandPort.command to injector2.commandInPort.command;
        flow ecuToInjector3 of FuelCommand from ecu.injector3CommandPort.command to injector3.commandInPort.command;
        flow ecuToInjector4 of FuelCommand from ecu.injector4CommandPort.command to injector4.commandInPort.command;
    }

    requirement def StableFuelPressure {
        doc "The fuel rail pressure must be maintained at 300 kPa +/- 5 kPa under all engine loads.";
    }
    requirement def OptimalAirFuelRatio {
        doc "The air-fuel mixture must be maintained near the stoichiometric ratio of 14.7:1 during closed-loop operation.";
    }
    requirement def LowEmissions {
        doc "The system must minimize harmful exhaust emissions by maintaining precise fuel metering and complete combustion.";
    }
    requirement def RealTimeFuelAdjustment {
        doc "The ECU shall perform constant real-time adjustments to fuel delivery based on sensor inputs.";
    }

    requirement stableFuelPressureReq : StableFuelPressure;
    requirement optimalAFRReq : OptimalAirFuelRatio;
    requirement lowEmissionsReq : LowEmissions;
    requirement realTimeAdjustmentReq : RealTimeFuelAdjustment;

    satisfy stableFuelPressureReq by EFISystem;
    satisfy optimalAFRReq by EFISystem;
    satisfy lowEmissionsReq by EFISystem;
    satisfy realTimeAdjustmentReq by ECUControlLoop;
}
