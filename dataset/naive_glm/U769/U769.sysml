package McLeodGaugeModel {
    import ScalarValues::*;
    
    unit pascal;
    unit cubicMeter;
    unit squareMeter;
    unit meter;
    unit percent;

    attribute def PressureValue :> Real { unit = pascal; }
    attribute def VolumeValue :> Real { unit = cubicMeter; }
    attribute def AreaValue :> Real { unit = squareMeter; }
    attribute def LengthValue :> Real { unit = meter; }
    attribute def PurityValue :> Real { unit = percent; }

    item def Gas;
    item def Mercury {
        attribute purity : PurityValue;
    }

    requirement def OperatingRange {
        doc /* The system is designed to operate within a specific range of low pressures. */
        attribute minPressure : PressureValue = 0.001 [pascal];
        attribute maxPressure : PressureValue = 100 [pascal];
        constraint { 0.001 [pascal] <= measuredPressure <= 100 [pascal] }
    }
    requirement def MercuryPurity {
        doc /* Relies on the high purity of the mercury for its precision. */
        attribute minPurity : PurityValue = 99.999 [percent];
        constraint { mercuryPurity >= 99.999 [percent] }
    }
    requirement def MeasurementAccuracy {
        doc /* The gauge must accurately measure low pressures. */
        attribute targetAccuracy : Real = 0.01;
    }

    port def VacuumPort {
        out item gas : Gas;
        in attribute pressure : PressureValue;
    }
    port def MercuryPort {
        out item mercury : Mercury;
    }

    part def Bulb {
        attribute volume : VolumeValue = 0.0001 [cubicMeter];
        port gasIn : VacuumPort;
        port mercuryIn : MercuryPort;
        attribute isFull : Boolean = false;
    }
    part def Capillary {
        attribute volume : VolumeValue = 0.000001 [cubicMeter];
        attribute crossSectionalArea : AreaValue = 0.000001 [squareMeter];
        port gasIn : VacuumPort;
        port mercuryIn : MercuryPort;
        attribute heightMeasured : Boolean = false;
    }
    part def Reservoir {
        port mercuryOut : MercuryPort;
        attribute baseLevel : LengthValue = 0.0 [meter];
    }

    part def McLeodGauge satisfies opRange : OperatingRange, purityReq : MercuryPurity, accReq : MeasurementAccuracy {
        port vacuumConnection : VacuumPort;
        
        attribute measuredPressure : PressureValue;
        attribute calculatedPressure : PressureValue;
        
        part bulb : Bulb;
        part capillary : Capillary;
        part reservoir : Reservoir;
        part mercurySupply : Mercury {
            attribute purity : PurityValue = 99.9999 [percent];
            attribute level : LengthValue = 0.0 [meter];
        }

        connection def GasFlow {
            end source : Gas;
            end target : Gas;
        }
        connection def MercuryFlow {
            end source : Mercury;
            end target : Mercury;
        }

        connection gasFlowToBulb : GasFlow connect vacuumConnection.gas to bulb.gasIn.gas;
        connection gasFlowToCapillary : GasFlow connect bulb.gasIn.gas to capillary.gasIn.gas;
        connection mercuryRaise : MercuryFlow connect reservoir.mercuryOut.mercury to bulb.mercuryIn.mercury;
        connection mercuryToCapillary : MercuryFlow connect bulb.mercuryIn.mercury to capillary.mercuryIn.mercury;

        state def MeasurementCycle {
            entry action calculateInitialVolume { /* calculate initial volume */ }
            state Ready;
            state FillingBulb;
            state TrappingGas;
            state CompressingGas;
            state MeasuringHeight;
            state CalculatingPressure;
            state LoweringMercury;

            transition ready_to_filling
                from Ready to FillingBulb
                when vacuumConnection.pressure > 0 [pascal];
            transition filling_to_trapping
                from FillingBulb to TrappingGas
                when bulb.isFull;
            transition trapping_to_compressing
                from TrappingGas to CompressingGas
                when mercurySupply.level > 0.05 [meter];
            transition compressing_to_measuring
                from CompressingGas to MeasuringHeight
                when mercurySupply.level > 0.1 [meter];
            transition measuring_to_calculating
                from MeasuringHeight to CalculatingPressure
                when capillary.heightMeasured;
            transition calculating_to_lowering
                from CalculatingPressure to LoweringMercury
                when calculatedPressure > 0 [pascal];
            transition lowering_to_ready
                from LoweringMercury to Ready
                when mercurySupply.level == reservoir.baseLevel;
        }

        part behavior : MeasurementCycle;
    }
}
