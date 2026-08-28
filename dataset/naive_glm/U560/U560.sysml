package IndustrialFluidPumpingSystem {
    import ScalarValues::*;
    import ISQ::*;

    // ---- Value types with units ----
    value type Pressure :> Real { unit "Pa"; }
    value type VolumeFlowRate :> Real { unit "m3/s"; }
    value type RotationalSpeed :> Real { unit "rad/s"; }
    value type Torque :> Real { unit "N*m"; }
    value type Efficiency :> Real { unit "1"; }
    value type Volume :> Real { unit "m3"; }
    value type Length :> Real { unit "m"; }
    value type Diameter :> Real { unit "m"; }
    value type Power :> Real { unit "W"; }

    // ---- Items ----
    item def Fluid;
    item def ElectricalEnergy;
    item def MechanicalEnergy;
    item def ControlSignal;

    // ---- Port definitions ----
    port def FluidPort {
        flow item fluid: Fluid;
        attribute pressure: Pressure;
    }

    port def MechanicalPort {
        flow item mechanicalEnergy: MechanicalEnergy;
        attribute torque: Torque;
        attribute speed: RotationalSpeed;
    }

    port def ElectricalPort {
        flow item electricalEnergy: ElectricalEnergy;
        attribute voltage: Real;
    }

    port def PressureTapPort {
        attribute pressure: Pressure;
    }

    port def FlowTapPort {
        attribute flowRate: VolumeFlowRate;
    }

    port def SignalOutPort {
        out attribute value: Real;
    }

    // ---- Connection definitions ----
    connection def FluidFlow connects FluidPort to FluidPort {
        flow fluid;
    }

    connection def MechanicalDrive connects MechanicalPort to MechanicalPort {
        flow mechanicalEnergy;
    }

    connection def ElectricalSupply connects ElectricalPort to ElectricalPort {
        flow electricalEnergy;
    }

    connection def PressureSensing connects PressureTapPort to PressureTapPort;
    connection def FlowSensing connects FlowTapPort to FlowTapPort;
    connection def SignalTransmission connects SignalOutPort to SignalOutPort;

    // ---- Part definitions ----
    part def SupplyTank {
        port outlet: FluidPort;
        attribute capacity: Volume = 10.0 [m3];
        attribute fluidLevel: Volume = 8.0 [m3];
        attribute storedFluid: Fluid;
    }

    part def ReceivingTank {
        port inlet: FluidPort;
        attribute capacity: Volume = 10.0 [m3];
        attribute fluidLevel: Volume = 0.0 [m3];
        attribute collectedFluid: Fluid;
    }

    part def HelicalScrewRotor {
        attribute length: Length = 0.5 [m];
        attribute diameter: Diameter = 0.1 [m];
        attribute pitch: Length = 0.08 [m];
        attribute rotationalSpeed: RotationalSpeed;
    }

    part def Casing {
        attribute innerDiameter: Diameter = 0.101 [m];
        attribute length: Length = 0.5 [m];
    }

    part def ScrewPump {
        port suctionPort: FluidPort;
        port dischargePort: FluidPort;
        port drivePort: MechanicalPort;
        port suctionTap: PressureTapPort;
        port dischargeTap: PressureTapPort;
        port flowTap: FlowTapPort;

        part rotor: HelicalScrewRotor;
        part casing: Casing;

        attribute ratedFlowRate: VolumeFlowRate = 0.01 [m3/s];
        attribute ratedPressure: Pressure = 500000 [Pa];
        attribute ratedSpeed: RotationalSpeed = 150 [rad/s];
        attribute volumetricEfficiency: Efficiency;
        attribute overallEfficiency: Efficiency;
        attribute inletPressure: Pressure;
        attribute outletPressure: Pressure;
        attribute generatedFlowRate: VolumeFlowRate;

        action def PumpFluid {
            in item inletFluid: Fluid;
            out item outletFluid: Fluid;
            in attribute driveTorque: Torque;
            in attribute driveSpeed: RotationalSpeed;
            out attribute dischargePressure: Pressure;
            out attribute actualFlowRate: VolumeFlowRate;
        }

        state def PumpOperation {
            entry action { /* initialize pump state */ }
            state Off {
                entry action { generatedFlowRate = 0.0 [m3/s]; }
            }
            state Starting {
                entry action { /* ramp up rotor speed */ }
            }
            state Running {
                entry action { /* steady-state pumping */ }
            }
            state Faulted {
                entry action { /* flag fault condition */ }
            }
            transition off_to_starting
                first Off to Starting
                when drivePort.torque > 0.0 [N*m];
            transition starting_to_running
                first Starting to Running
                when rotor.rotationalSpeed >= ratedSpeed * 0.95;
            transition running_to_faulted
                first Running to Faulted
                when outletPressure > ratedPressure * 1.2;
            transition faulted_to_off
                first Faulted to Off
                when drivePort.torque == 0.0 [N*m];
        }
    }

    part def ElectricMotor {
        port electricalIn: ElectricalPort;
        port mechanicalOut: MechanicalPort;
        attribute ratedSpeed: RotationalSpeed = 150 [rad/s];
        attribute ratedTorque: Torque = 50.0 [N*m];
        attribute ratedPower: Power = 7500.0 [W];
        attribute efficiency: Efficiency = 0.92;

        action def ConvertEnergy {
            in item electricalEnergy: ElectricalEnergy;
            out item mechanicalEnergy: MechanicalEnergy;
        }
    }

    part def DriveShaft {
        port motorEnd: MechanicalPort;
        port pumpEnd: MechanicalPort;
        attribute length: Length = 0.3 [m];
        attribute diameter: Diameter = 0.03 [m];
    }

    part def PressureGauge {
        port measurePort: PressureTapPort;
        port signalOut: SignalOutPort;
        attribute measuredPressure: Pressure;
        attribute measurementRange: Pressure = 1000000 [Pa];

        action def MeasurePressure {
            in attribute sensedPressure: Pressure;
            out attribute reading: Real;
        }
    }

    part def FlowMeter {
        port measurePort: FlowTapPort;
        port signalOut: SignalOutPort;
        attribute measuredFlowRate: VolumeFlowRate;
        attribute measurementRange: VolumeFlowRate = 0.1 [m3/s];

        action def MeasureFlow {
            in attribute sensedFlow: VolumeFlowRate;
            out attribute reading: Real;
        }
    }

    part def PumpController {
        port inletPressureSignal: SignalOutPort;
        port outletPressureSignal: SignalOutPort;
        port flowRateSignal: SignalOutPort;
        port motorCommand: SignalOutPort;
        attribute targetFlowRate: VolumeFlowRate = 0.01 [m3/s];
        attribute minEfficiency: Efficiency = 0.75;
        attribute maxOutletPressure: Pressure = 600000 [Pa];

        action def MonitorPerformance {
            in attribute inletP: Pressure;
            in attribute outletP: Pressure;
            in attribute flow: VolumeFlowRate;
            out attribute command: Real;
        }
    }

    // ---- Requirements ----
    requirement def FlowRateRequirement {
        subject pump: ScrewPump;
        attribute requiredFlowRate: VolumeFlowRate = 0.01 [m3/s];
        objective {
            pump.generatedFlowRate >= requiredFlowRate
        }
    }

    requirement def PressureLimitRequirement {
        subject pump: ScrewPump;
        attribute maxRatedPressure: Pressure = 500000 [Pa];
        objective {
            pump.outletPressure <= maxRatedPressure * 1.1
        }
    }

    requirement def EfficiencyRequirement {
        subject pump: ScrewPump;
        attribute minimumEfficiency: Efficiency = 0.75;
        objective {
            pump.overallEfficiency >= minimumEfficiency
        }
    }

    requirement def SuctionPressureRequirement {
        subject pump: ScrewPump;
        attribute minSuctionPressure: Pressure = 80000 [Pa];
        objective {
            pump.inletPressure >= minSuctionPressure
        }
    }

    // ---- System assembly ----
    part pumpingSystem {
        part supplyTank: SupplyTank {
            attribute storedFluid = Fluid{};
        }
        part pump: ScrewPump {
            part rotor: HelicalScrewRotor;
            part casing: Casing;
        }
        part receivingTank: ReceivingTank;
        part motor: ElectricMotor;
        part driveShaft: DriveShaft;
        part inletGauge: PressureGauge;
        part outletGauge: PressureGauge;
        part flowMeter: FlowMeter;
        part controller: PumpController;

        connection supplyToPump: FluidFlow
            connect supplyTank.outlet to pump.suctionPort;
        connection pumpToReceiving: FluidFlow
            connect pump.dischargePort to receivingTank.inlet;
        connection motorToShaft: MechanicalDrive
            connect motor.mechanicalOut to driveShaft.motorEnd;
        connection shaftToPump: MechanicalDrive
            connect driveShaft.pumpEnd to pump.drivePort;
        connection inletPressureSensing: PressureSensing
            connect pump.suctionTap to inletGauge.measurePort;
        connection outletPressureSensing: PressureSensing
            connect pump.dischargeTap to outletGauge.measurePort;
        connection flowSensing: FlowSensing
            connect pump.flowTap to flowMeter.measurePort;
        connection inletSignal: SignalTransmission
            connect inletGauge.signalOut to controller.inletPressureSignal;
        connection outletSignal: SignalTransmission
            connect outletGauge.signalOut to controller.outletPressureSignal;
        connection flowSignal: SignalTransmission
            connect flowMeter.signalOut to controller.flowRateSignal;

        requirement flowRateReq : FlowRateRequirement {
            subject pump = pump;
        }
        requirement pressureLimitReq : PressureLimitRequirement {
            subject pump = pump;
        }
        requirement efficiencyReq : EfficiencyRequirement {
            subject pump = pump;
        }
        requirement suctionPressureReq : SuctionPressureRequirement {
            subject pump = pump;
        }
    }
}
