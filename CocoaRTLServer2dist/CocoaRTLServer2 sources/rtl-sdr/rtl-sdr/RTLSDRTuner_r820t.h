//
//  RTLSDRTuner_r820t.h
//  rtl-sdr
//
//  Created by William Dillon on 10/14/12.
//
//

//
// Mmodified 2016 by Chris Smolinski
//

#import <RTLSDRTuner.h>

#define R820T_I2C_ADDR		0x34
#define R820T_CHECK_ADDR	0x00
#define R820T_CHECK_VAL		0x69

#define R820T_IF_FREQ		3570000


#define USE_16M_XTAL		FALSE
#define R828_Xtal		28800

#define USE_DIPLEXER		FALSE
#define TUNER_CLK_OUT		TRUE

#define FUNCTION_SUCCESS	0
#define FUNCTION_ERROR		-1

typedef enum _R828_ErrCode
{
	RT_Success,
	RT_Fail
}R828_ErrCode;

typedef enum _Rafael_Chip_Type  //Don't modify chip list
{
	R828 = 0,
	R828D,
	R828S,
	R820T,
	R820C,
	R620D,
	R620S
}Rafael_Chip_Type;
//----------------------------------------------------------//
//                   R828 Parameter                        //
//----------------------------------------------------------//
#define VERSION   "R820T_v1.49_ASTRO"
#define VER_NUM  49

extern uint8 R828_ADDRESS;

#define DIP_FREQ  	  320000
#define IMR_TRIAL    9
#define VCO_pwr_ref   0x02

extern uint32 R828_IF_khz;
extern uint32 R828_CAL_LO_khz;
extern uint8  R828_IMR_point_num;
extern uint8  R828_IMR_done_flag;
extern uint8  Rafael_Chip;

typedef enum _R828_Standard_Type  //Don't remove standand list!!
{
	NTSC_MN = 0,
	PAL_I,
	PAL_DK,
	PAL_B_7M,       //no use
	PAL_BGH_8M,     //for PAL B/G, PAL G/H
	SECAM_L,
	SECAM_L1_INV,   //for SECAM L'
	SECAM_L1,       //no use
	ATV_SIZE,
	DVB_T_6M = ATV_SIZE,
	DVB_T_7M,
	DVB_T_7M_2,
	DVB_T_8M,
	DVB_T2_6M,
	DVB_T2_7M,
	DVB_T2_7M_2,
	DVB_T2_8M,
	DVB_T2_1_7M,
	DVB_T2_10M,
	DVB_C_8M,
	DVB_C_6M,
	ISDB_T,
	DTMB,
	R828_ATSC,
	FM,
	STD_SIZE
}R828_Standard_Type;

extern uint8  R828_Fil_Cal_flag[STD_SIZE];

typedef enum _R828_SetFreq_Type
{
	FAST_MODE = TRUE,
	NORMAL_MODE = FALSE
}R828_SetFreq_Type;

typedef enum _R828_LoopThrough_Type
{
	LOOP_THROUGH = TRUE,
	SIGLE_IN     = FALSE
}R828_LoopThrough_Type;


typedef enum _R828_InputMode_Type
{
	AIR_IN = 0,
	CABLE_IN_1,
	CABLE_IN_2
}R828_InputMode_Type;

typedef enum _R828_IfAgc_Type
{
	IF_AGC1 = 0,
	IF_AGC2
}R828_IfAgc_Type;

typedef enum _R828_GPIO_Type
{
	HI_SIG = TRUE,
	LO_SIG = FALSE
}R828_GPIO_Type;

typedef struct _R828_Set_Info
{
	uint32        RF_Hz;
	uint32        RF_KHz;
	R828_Standard_Type R828_Standard;
	R828_LoopThrough_Type RT_Input;
	R828_InputMode_Type   RT_InputMode;
	R828_IfAgc_Type R828_IfAgc_Select;
}R828_Set_Info;

typedef struct _R828_RF_Gain_Info
{
	uint8   RF_gain1;
	uint8   RF_gain2;
	uint8   RF_gain_comb;
}R828_RF_Gain_Info;

typedef enum _R828_RF_Gain_TYPE
{
	RF_AUTO = 0,
	RF_MANUAL
}R828_RF_Gain_TYPE;

typedef struct _R828_I2C_LEN_TYPE
{
	uint8 RegAddr;
	uint8 Data[50];
	uint8 Len;
}R828_I2C_LEN_TYPE;

typedef struct _R828_I2C_TYPE
{
	uint8 RegAddr;
	uint8 Data;
}R828_I2C_TYPE;

@interface RTLSDRTuner_r820t : RTLSDRTuner
{
    double offset;
}

@end
