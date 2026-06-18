package PumpingSubsystemModel {
    import ScalarValues::*;
    import SI::*;
    import ISQ::*;

    unit def kilowatt {
        symbol = "kW";
        conversionFactor = 1000.0;
        referenceUnit = watt;
    }

    unit def kilopascal {
        symbol = "kPa";
        conversionFactor = 1000.0;
        referenceUnit = pascal;
    }

    unit def literPerSecond {
        symbol = "L/s";
        conversionFactor = 0.001;
        referenceUnit = cubicMetre / second;
    }

    unit def kilogramPerSecond {
        symbol = "kg/s";
        referenceUnit = kilogram / second;
    }

    unit def joulePerKilogram {
        symbol = "J/kg";
        referenceUnit = joule / kilogram;
    }

    unit def revolutionPerMinute {
        symbol = "rpm";
        referenceUnit = one / minute;
    }

    unit def ampereHour {
        symbol = "Ah";
        referenceUnit = ampere * hour;
    }

    value def Pressure {
        :> ISQ::pressure;
        unit = pascal;
    }

    value def Temperature {
        :> ISQ::thermodynamicTemperature;
        unit = kelvin;
    }

    value def Density {
        :> ISQ::density;
        unit = kilogram / cubicMetre;
    }

    value def DynamicViscosity {
        :> ISQ::dynamicViscosity;
        unit = pascal * second;
    }

    value def VolumetricFlowRate {
        :> ISQ::volumeFlowRate;
        unit = cubicMetre / second;
    }

    value def MassFlowRate {
        :> ISQ::massFlowRate;
        unit = kilogramPerSecond;
    }

    value def Power {
        :> ISQ::power;
        unit = watt;
    }

    value def SpecificPumpPower {
        :> ISQ::specificEnergy;
        unit = joulePerKilogram;
    }

    value def RotationalSpeed {
        :> ISQ::angularVelocity;
        unit = revolutionPerMinute;
    }

    value def Efficiency {
        :> ScalarValues::Real;
        unit = one;
    }

    value def ElectricPotential {
        :> ISQ::voltage;
        unit = volt;
    }

    value def ElectricCurrent {
        :> ISQ::electricCurrent;
        unit = ampere;
    }

    value def Energy {
        :> ISQ::energy;
        unit = joule;
    }

    item def PumpedFluid {
        attribute pressure: Pressure;
        attribute temperature: Temperature;
        attribute density: Density;
        attribute dynamicViscosity: DynamicViscosity;
        attribute volumetricFlowRate: VolumetricFlowRate;
        attribute massFlowRate: MassFlowRate;
    }

    item def PumpedFluidAtSuction :> PumpedFluid {
        attribute pressure = 150.0 [kilopascal];
        attribute temperature = 293.15 [kelvin];
        attribute density = 998.0 [kilogram / cubicMetre];
        attribute dynamicViscosity = 0.001 [pascal * second];
        attribute volumetricFlowRate = 0.020 [cubicMetre / second];
        attribute massFlowRate = 19.96 [kilogramPerSecond];
    }

    item def PumpedFluidAtDischarge :> PumpedFluid {
        attribute pressure = 1748.0 [kilopascal];
        attribute temperature = 294.15 [kelvin];
        attribute density = 998.0 [kilogram / cubicMetre];
        attribute dynamicViscosity = 0.001 [pascal * second];
        attribute volumetricFlowRate = 0.020 [cubicMetre / second];
        attribute massFlowRate = 19.96 [kilogramPerSecond];
    }

    item def ElectricalPower {
        attribute voltage: ElectricPotential;
        attribute current: ElectricCurrent;
        attribute power: Power;
    }

    item def MechanicalShaftPower {
        attribute shaftSpeed: RotationalSpeed;
        attribute torquePower: Power;
    }

    item def StartCommand {
        attribute requestedSpecificPumpPower: SpecificPumpPower;
        attribute requestedMassFlowRate: MassFlowRate;
    }

    item def StopCommand {
        attribute controlledStop: Boolean;
    }

    item def FaultSignal {
        attribute dryRunDetected: Boolean;
        attribute cavitationDetected: Boolean;
        attribute overCurrentDetected: Boolean;
        attribute overPressureDetected: Boolean;
        attribute message: String;
    }

    port def FluidInletPort {
        in item fluid: PumpedFluid;
        attribute measuredPressure: Pressure;
        attribute measuredTemperature: Temperature;
        attribute measuredMassFlowRate: MassFlowRate;
    }

    port def FluidOutletPort {
        out item fluid: PumpedFluid;
        attribute measuredPressure: Pressure;
        attribute measuredTemperature: Temperature;
        attribute measuredMassFlowRate: MassFlowRate;
    }

    port def ElectricalPowerPort {
        in item electricalPower: ElectricalPower;
        attribute voltage: ElectricPotential;
        attribute current: ElectricCurrent;
        attribute realPower: Power;
    }

    port def MechanicalPowerOutPort {
        out item shaftPower: MechanicalShaftPower;
        attribute shaftSpeed: RotationalSpeed;
        attribute deliveredPower: Power;
    }

    port def MechanicalPowerInPort {
        in item shaftPower: MechanicalShaftPower;
        attribute shaftSpeed: RotationalSpeed;
        attribute receivedPower: Power;
    }

    port def CommandPort {
        in item start: StartCommand;
        in item stop: StopCommand;
    }

    port def FaultPort {
        out item fault: FaultSignal;
    }

    port def MeasurementPort {
        out attribute pressure: Pressure;
        out attribute massFlowRate: MassFlowRate;
        out attribute power: Power;
        out attribute specificPumpPower: SpecificPumpPower;
    }

    connection def FluidTransfer {
        end upstream: FluidOutletPort;
        end downstream: FluidInletPort;
    }

    connection def ElectricalSupply {
        end source: ElectricalPowerPort;
        end load: ElectricalPowerPort;
    }

    connection def ShaftCoupling {
        end driver: MechanicalPowerOutPort;
        end driven: MechanicalPowerInPort;
    }

    constraint def SpecificPumpPowerEquation {
        in shaftPower: Power;
        in massFlowRate: MassFlowRate;
        out specificPumpPower: SpecificPumpPower;

        assert constraint {
            specificPumpPower == shaftPower / massFlowRate
        }
    }

    constraint def HydraulicSpecificEnergyEquation {
        in pressureRise: Pressure;
        in density: Density;
        out hydraulicSpecificEnergy: SpecificPumpPower;

        assert constraint {
            hydraulicSpecificEnergy == pressureRise / density
        }
    }

    constraint def PumpEfficiencyEquation {
        in hydraulicSpecificEnergy: SpecificPumpPower;
        in shaftSpecificPumpPower: SpecificPumpPower;
        out pumpEfficiency: Efficiency;

        assert constraint {
            pumpEfficiency == hydraulicSpecificEnergy / shaftSpecificPumpPower
        }
    }

    constraint def MassContinuityEquation {
        in suctionMassFlowRate: MassFlowRate;
        in dischargeMassFlowRate: MassFlowRate;

        assert constraint {
            suctionMassFlowRate == dischargeMassFlowRate
        }
    }

    constraint def PressureRiseEquation {
        in suctionPressure: Pressure;
        in dischargePressure: Pressure;
        out pressureRise: Pressure;

        assert constraint {
            pressureRise == dischargePressure - suctionPressure
        }
    }

    action def PrimePump {
        in suctionFluid: PumpedFluid;
        out primedFluid: PumpedFluid;
        attribute minimumPrimingPressure: Pressure = 120.0 [kilopascal];

        precondition {
            suctionFluid.pressure >= minimumPrimingPressure
        }

        postcondition {
            primedFluid.massFlowRate == suctionFluid.massFlowRate
        }
    }

    action def AcceleratePump {
        in targetSpecificPumpPower: SpecificPumpPower;
        in targetMassFlowRate: MassFlowRate;
        out commandedSpeed: RotationalSpeed;
        out commandedShaftPower: Power;

        attribute nominalRampRate: RotationalSpeed = 300.0 [revolutionPerMinute];

        postcondition {
            commandedShaftPower == targetSpecificPumpPower * targetMassFlowRate
        }
    }

    action def MoveFluidUsingSpecificPumpPower {
        in fluidAtSuction: PumpedFluidAtSuction;
        in shaftPower: MechanicalShaftPower;
        out fluidAtDischarge: PumpedFluidAtDischarge;

        attribute commandedSpecificPumpPower: SpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute nominalMassFlowRate: MassFlowRate = 19.96 [kilogramPerSecond];
        attribute nominalShaftPower: Power = 49.9 [kilowatt];
        attribute hydraulicSpecificEnergy: SpecificPumpPower = 1600.0 [joulePerKilogram];
        attribute pumpHydraulicEfficiency: Efficiency = 0.64;
        attribute nominalPressureRise: Pressure = 1596.8 [kilopascal];

        bind fluidAtSuction.massFlowRate = fluidAtDischarge.massFlowRate;

        assert constraint {
            nominalShaftPower == commandedSpecificPumpPower * nominalMassFlowRate
        }

        assert constraint {
            hydraulicSpecificEnergy == commandedSpecificPumpPower * pumpHydraulicEfficiency
        }

        assert constraint {
            nominalPressureRise == fluidAtSuction.density * hydraulicSpecificEnergy
        }

        assert constraint {
            fluidAtDischarge.pressure == fluidAtSuction.pressure + nominalPressureRise
        }
    }

    action def RegulateSpecificPumpPower {
        in measuredShaftPower: Power;
        in measuredMassFlowRate: MassFlowRate;
        in requestedSpecificPumpPower: SpecificPumpPower;
        out speedCorrection: RotationalSpeed;
        out achievedSpecificPumpPower: SpecificPumpPower;

        attribute allowableSpecificPowerError: SpecificPumpPower = 125.0 [joulePerKilogram];

        assert constraint {
            achievedSpecificPumpPower == measuredShaftPower / measuredMassFlowRate
        }

        postcondition {
            achievedSpecificPumpPower >= requestedSpecificPumpPower - allowableSpecificPowerError and
            achievedSpecificPumpPower <= requestedSpecificPumpPower + allowableSpecificPowerError
        }
    }

    action def StopPump {
        in stopCommand: StopCommand;
        out finalShaftPower: Power;

        postcondition {
            finalShaftPower == 0.0 [watt]
        }
    }

    state def PumpOperatingStates {
        attribute requestedSpecificPumpPower: SpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute measuredSpecificPumpPower: SpecificPumpPower;
        attribute measuredMassFlowRate: MassFlowRate;
        attribute measuredShaftPower: Power;

        state stopped;
        state priming;
        state accelerating;
        state runningAtSpecificPumpPower;
        state controlledStopping;
        state faulted;

        initial then stopped;

        transition startToPriming
            first stopped
            accept StartCommand
            do PrimePump
            then priming;

        transition primedToAccelerating
            first priming
            if measuredMassFlowRate > 1.0 [kilogramPerSecond]
            do AcceleratePump
            then accelerating;

        transition acceleratedToRunning
            first accelerating
            if measuredSpecificPumpPower >= requestedSpecificPumpPower - 125.0 [joulePerKilogram] and
               measuredSpecificPumpPower <= requestedSpecificPumpPower + 125.0 [joulePerKilogram]
            then runningAtSpecificPumpPower;

        transition regulateWhileRunning
            first runningAtSpecificPumpPower
            if measuredMassFlowRate > 0.0 [kilogramPerSecond]
            do RegulateSpecificPumpPower
            then runningAtSpecificPumpPower;

        transition runningToControlledStopping
            first runningAtSpecificPumpPower
            accept StopCommand
            do StopPump
            then controlledStopping;

        transition stoppedAfterControlledStop
            first controlledStopping
            if measuredShaftPower <= 100.0 [watt]
            then stopped;

        transition dryRunFault
            first runningAtSpecificPumpPower
            accept FaultSignal
            if measuredMassFlowRate < 0.5 [kilogramPerSecond]
            then faulted;

        transition overPowerFault
            first runningAtSpecificPumpPower
            if measuredSpecificPumpPower > 3000.0 [joulePerKilogram]
            then faulted;
    }

    part def SuctionStrainer {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute cleanPressureDrop: Pressure = 20.0 [kilopascal];
        attribute maximumAllowedPressureDrop: Pressure = 70.0 [kilopascal];
        attribute meshOpening: LengthValue = 0.0015 [metre];

        assert constraint {
            outlet.measuredPressure == inlet.measuredPressure - cleanPressureDrop
        }
    }

    part def IsolationValve {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute commandedOpen: Boolean = true;
        attribute fullOpenPressureDrop: Pressure = 5.0 [kilopascal];

        assert constraint {
            commandedOpen implies outlet.measuredPressure == inlet.measuredPressure - fullOpenPressureDrop
        }
    }

    part def VariableSpeedMotor {
        port electricalInput: ElectricalPowerPort;
        port shaftOutput: MechanicalPowerOutPort;
        port commandInput: CommandPort;
        port faultOutput: FaultPort;

        attribute ratedElectricalPower: Power = 75.0 [kilowatt];
        attribute ratedVoltage: ElectricPotential = 480.0 [volt];
        attribute ratedCurrent: ElectricCurrent = 115.0 [ampere];
        attribute nominalMotorEfficiency: Efficiency = 0.94;
        attribute minimumSpeed: RotationalSpeed = 600.0 [revolutionPerMinute];
        attribute maximumSpeed: RotationalSpeed = 3600.0 [revolutionPerMinute];
        attribute commandedSpeed: RotationalSpeed = 2400.0 [revolutionPerMinute];

        assert constraint {
            shaftOutput.deliveredPower == electricalInput.realPower * nominalMotorEfficiency
        }

        assert constraint {
            commandedSpeed >= minimumSpeed and commandedSpeed <= maximumSpeed
        }
    }

    part def FlexibleShaftCoupling {
        port motorSide: MechanicalPowerInPort;
        port pumpSide: MechanicalPowerOutPort;

        attribute couplingEfficiency: Efficiency = 0.99;
        attribute maximumTransmitPower: Power = 90.0 [kilowatt];

        assert constraint {
            pumpSide.deliveredPower == motorSide.receivedPower * couplingEfficiency
        }

        assert constraint {
            pumpSide.deliveredPower <= maximumTransmitPower
        }
    }

    part def CentrifugalPumpElement {
        port suction: FluidInletPort;
        port discharge: FluidOutletPort;
        port shaftInput: MechanicalPowerInPort;
        port measurementOutput: MeasurementPort;

        attribute designSpecificPumpPower: SpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute minimumSpecificPumpPower: SpecificPumpPower = 2375.0 [joulePerKilogram];
        attribute maximumSpecificPumpPower: SpecificPumpPower = 2625.0 [joulePerKilogram];
        attribute nominalMassFlowRate: MassFlowRate = 19.96 [kilogramPerSecond];
        attribute nominalShaftPower: Power = 49.9 [kilowatt];
        attribute nominalHydraulicEfficiency: Efficiency = 0.64;
        attribute nominalHydraulicSpecificEnergy: SpecificPumpPower = 1600.0 [joulePerKilogram];
        attribute nominalPressureRise: Pressure = 1596.8 [kilopascal];
        attribute minimumNetPositiveSuctionPressure: Pressure = 90.0 [kilopascal];

        bind suction.measuredMassFlowRate = discharge.measuredMassFlowRate;
        bind measurementOutput.massFlowRate = discharge.measuredMassFlowRate;
        bind measurementOutput.power = shaftInput.receivedPower;

        assert constraint {
            measurementOutput.specificPumpPower == shaftInput.receivedPower / discharge.measuredMassFlowRate
        }

        assert constraint {
            nominalShaftPower == designSpecificPumpPower * nominalMassFlowRate
        }

        assert constraint {
            nominalHydraulicSpecificEnergy == designSpecificPumpPower * nominalHydraulicEfficiency
        }

        assert constraint {
            nominalPressureRise == suction.fluid.density * nominalHydraulicSpecificEnergy
        }

        assert constraint {
            discharge.measuredPressure == suction.measuredPressure + nominalPressureRise
        }

        assert constraint {
            suction.measuredPressure >= minimumNetPositiveSuctionPressure
        }
    }

    part def DischargeCheckValve {
        port inlet: FluidInletPort;
        port outlet: FluidOutletPort;

        attribute forwardPressureDrop: Pressure = 15.0 [kilopascal];
        attribute reverseFlowBlocked: Boolean = true;

        assert constraint {
            outlet.measuredPressure == inlet.measuredPressure - forwardPressureDrop
        }
    }

    part def PressureTransmitter {
        port processConnection: FluidInletPort;
        port measurement: MeasurementPort;

        attribute rangeLow: Pressure = 0.0 [kilopascal];
        attribute rangeHigh: Pressure = 2500.0 [kilopascal];
        attribute accuracy: Pressure = 2.5 [kilopascal];

        bind measurement.pressure = processConnection.measuredPressure;

        assert constraint {
            processConnection.measuredPressure >= rangeLow and
            processConnection.measuredPressure <= rangeHigh
        }
    }

    part def FlowMeter {
        port processConnection: FluidInletPort;
        port measurement: MeasurementPort;

        attribute rangeLow: MassFlowRate = 0.0 [kilogramPerSecond];
        attribute rangeHigh: MassFlowRate = 30.0 [kilogramPerSecond];
        attribute accuracy: MassFlowRate = 0.15 [kilogramPerSecond];

        bind measurement.massFlowRate = processConnection.measuredMassFlowRate;

        assert constraint {
            processConnection.measuredMassFlowRate >= rangeLow and
            processConnection.measuredMassFlowRate <= rangeHigh
        }
    }

    part def PumpController {
        port commandPort: CommandPort;
        port pumpMeasurement: MeasurementPort;
        port motorCommand: CommandPort;
        port faultPort: FaultPort;

        attribute requestedSpecificPumpPower: SpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute allowableSpecificPumpPowerTolerance: SpecificPumpPower = 125.0 [joulePerKilogram];
        attribute minimumAllowedMassFlowRate: MassFlowRate = 1.0 [kilogramPerSecond];
        attribute maximumAllowedSpecificPumpPower: SpecificPumpPower = 3000.0 [joulePerKilogram];

        perform regulation: RegulateSpecificPumpPower;

        assert constraint {
            pumpMeasurement.specificPumpPower >= requestedSpecificPumpPower - allowableSpecificPumpPowerTolerance and
            pumpMeasurement.specificPumpPower <= requestedSpecificPumpPower + allowableSpecificPumpPowerTolerance
        }
    }

    part def PumpingSubsystem {
        port suctionInterface: FluidInletPort;
        port dischargeInterface: FluidOutletPort;
        port electricalSupplyInterface: ElectricalPowerPort;
        port operatorCommandInterface: CommandPort;
        port subsystemFaultInterface: FaultPort;
        port subsystemMeasurementInterface: MeasurementPort;

        part suctionValve: IsolationValve;
        part suctionStrainer: SuctionStrainer;
        part pump: CentrifugalPumpElement;
        part motor: VariableSpeedMotor;
        part coupling: FlexibleShaftCoupling;
        part dischargeCheckValve: DischargeCheckValve;
        part dischargeValve: IsolationValve;
        part suctionPressureTransmitter: PressureTransmitter;
        part dischargePressureTransmitter: PressureTransmitter;
        part flowMeter: FlowMeter;
        part controller: PumpController;

        attribute requiredSpecificPumpPower: SpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute specificPumpPowerTolerance: SpecificPumpPower = 125.0 [joulePerKilogram];
        attribute nominalMassFlowRate: MassFlowRate = 19.96 [kilogramPerSecond];
        attribute nominalShaftPower: Power = 49.9 [kilowatt];
        attribute nominalElectricalPower: Power = 53.6 [kilowatt];
        attribute nominalSuctionPressure: Pressure = 150.0 [kilopascal];
        attribute nominalDischargePressure: Pressure = 1713.0 [kilopascal];
        attribute nominalNetPressureRise: Pressure = 1563.0 [kilopascal];
        attribute fluidDensity: Density = 998.0 [kilogram / cubicMetre];

        connection suctionToValve: FluidTransfer connect suctionInterface to suctionValve.inlet;
        connection valveToStrainer: FluidTransfer connect suctionValve.outlet to suctionStrainer.inlet;
        connection strainerToPump: FluidTransfer connect suctionStrainer.outlet to pump.suction;
        connection pumpToCheckValve: FluidTransfer connect pump.discharge to dischargeCheckValve.inlet;
        connection checkValveToDischargeValve: FluidTransfer connect dischargeCheckValve.outlet to dischargeValve.inlet;
        connection valveToDischarge: FluidTransfer connect dischargeValve.outlet to dischargeInterface;

        connection electricalToMotor: ElectricalSupply connect electricalSupplyInterface to motor.electricalInput;
        connection motorToCoupling: ShaftCoupling connect motor.shaftOutput to coupling.motorSide;
        connection couplingToPump: ShaftCoupling connect coupling.pumpSide to pump.shaftInput;

        connection suctionPressureMeasurement connect suctionPressureTransmitter.processConnection to pump.suction;
        connection dischargePressureMeasurement connect dischargePressureTransmitter.processConnection to pump.discharge;
        connection flowMeasurement connect flowMeter.processConnection to pump.discharge;

        connection operatorCommandToController connect operatorCommandInterface to controller.commandPort;
        connection controllerCommandToMotor connect controller.motorCommand to motor.commandInput;
        connection controllerFaultToSubsystem connect controller.faultPort to subsystemFaultInterface;
        connection motorFaultToSubsystem connect motor.faultOutput to subsystemFaultInterface;
        connection pumpMeasurementToController connect pump.measurementOutput to controller.pumpMeasurement;
        connection pumpMeasurementToSubsystem connect pump.measurementOutput to subsystemMeasurementInterface;

        exhibit operatingStates: PumpOperatingStates;

        perform movingFluid: MoveFluidUsingSpecificPumpPower;

        assert constraint {
            nominalShaftPower == requiredSpecificPumpPower * nominalMassFlowRate
        }

        assert constraint {
            subsystemMeasurementInterface.specificPumpPower >= requiredSpecificPumpPower - specificPumpPowerTolerance and
            subsystemMeasurementInterface.specificPumpPower <= requiredSpecificPumpPower + specificPumpPowerTolerance
        }

        assert constraint {
            suctionInterface.measuredMassFlowRate == dischargeInterface.measuredMassFlowRate
        }

        assert constraint {
            dischargeInterface.measuredPressure > suctionInterface.measuredPressure
        }
    }

    requirement def MoveFluidRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* The pumping subsystem shall move pumped fluid from the suction interface to the discharge interface whenever commanded to run. */

        require constraint {
            subsystem.dischargeInterface.measuredMassFlowRate == subsystem.suctionInterface.measuredMassFlowRate
        }

        require constraint {
            subsystem.dischargeInterface.measuredPressure > subsystem.suctionInterface.measuredPressure
        }
    }

    requirement def SpecificPumpPowerRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* While running, the pumping subsystem shall use a specific pump power of 2500 J/kg with an allowable tolerance of plus or minus 125 J/kg. */

        require constraint {
            subsystem.subsystemMeasurementInterface.specificPumpPower >= 2375.0 [joulePerKilogram] and
            subsystem.subsystemMeasurementInterface.specificPumpPower <= 2625.0 [joulePerKilogram]
        }
    }

    requirement def NominalCapacityRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* At nominal operation, the subsystem shall deliver 19.96 kg/s of pumped fluid. */

        require constraint {
            subsystem.dischargeInterface.measuredMassFlowRate >= 19.0 [kilogramPerSecond] and
            subsystem.dischargeInterface.measuredMassFlowRate <= 21.0 [kilogramPerSecond]
        }
    }

    requirement def PowerBalanceRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* The nominal shaft power shall equal mass flow rate multiplied by required specific pump power. */

        require constraint {
            subsystem.nominalShaftPower == subsystem.nominalMassFlowRate * subsystem.requiredSpecificPumpPower
        }
    }

    requirement def SafeSuctionRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* The subsystem shall protect the pump from dry running by requiring adequate suction pressure before sustained operation. */

        require constraint {
            subsystem.pump.suction.measuredPressure >= subsystem.pump.minimumNetPositiveSuctionPressure
        }
    }

    requirement def OverSpecificPowerProtectionRequirement {
        subject subsystem: PumpingSubsystem;

        doc /* The subsystem shall transition to faulted operation if measured specific pump power exceeds 3000 J/kg. */

        require constraint {
            subsystem.controller.maximumAllowedSpecificPumpPower == 3000.0 [joulePerKilogram]
        }
    }

    action def VerifySpecificPumpPower {
        in testSubsystem: PumpingSubsystem;
        out passed: Boolean;

        attribute measuredPower: Power;
        attribute measuredMassFlowRate: MassFlowRate;
        attribute calculatedSpecificPumpPower: SpecificPumpPower;

        assert constraint {
            calculatedSpecificPumpPower == measuredPower / measuredMassFlowRate
        }

        postcondition {
            passed == (
                calculatedSpecificPumpPower >= 2375.0 [joulePerKilogram] and
                calculatedSpecificPumpPower <= 2625.0 [joulePerKilogram]
            )
        }
    }

    part pumpingSubsystem: PumpingSubsystem {
        attribute requiredSpecificPumpPower = 2500.0 [joulePerKilogram];
        attribute nominalMassFlowRate = 19.96 [kilogramPerSecond];
        attribute nominalShaftPower = 49.9 [kilowatt];
        attribute nominalElectricalPower = 53.6 [kilowatt];
        attribute nominalSuctionPressure = 150.0 [kilopascal];
        attribute nominalDischargePressure = 1713.0 [kilopascal];
    }

    satisfy MoveFluidRequirement by pumpingSubsystem;
    satisfy SpecificPumpPowerRequirement by pumpingSubsystem;
    satisfy NominalCapacityRequirement by pumpingSubsystem;
    satisfy PowerBalanceRequirement by pumpingSubsystem;
    satisfy SafeSuctionRequirement by pumpingSubsystem;
    satisfy OverSpecificPowerProtectionRequirement by pumpingSubsystem;

    action specificPumpPowerVerification: VerifySpecificPumpPower {
        in testSubsystem = pumpingSubsystem;
    }

    verify SpecificPumpPowerRequirement by specificPumpPowerVerification;
}
