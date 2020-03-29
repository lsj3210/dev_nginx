/**
 * Created by Lijian.
 * User: Lijian <lijian@demo.com.cn>
 * Date: 2019/9/2
 * Desc: abtest plugin 
**/

#include <iostream>
#include <vector>
#include <string>
#include <stdlib.h>

using namespace std;

#ifdef __cplusplus
extern "C"
{
    #include <lua.h>
    #include <lualib.h>
    #include <lauxlib.h>
    int luaopen_algorithm(lua_State*);
}
#else
    #include <lua.h>
    #include <lualib.h>
    #include <lauxlib.h>
#endif

void comm_ss(vector<string> &result, const string &s, string seperator){
    typedef string::size_type string_size;
    string_size i = 0;
    while(i != s.size()){
        int flag = 0;
        while(i != s.size() && flag == 0){
            flag = 1;
            for (string_size x = 0; x < seperator.size(); ++x) {
                if (s[i] == seperator[x]) {
                    ++i; flag = 0; break;
                }
            }
        }

        flag = 0;
        string_size j = i;
        while(j != s.size() && flag == 0) {
            for(string_size x = 0; x < seperator.size(); ++x) {
                if(s[j] == seperator[x]){
                    flag = 1; break;
                }
            }
            if(flag == 0) { ++j; }
        }
        if(i != j){
            result.push_back(s.substr(i, j-i));
            i = j;
        }
    }
}

void mask_convert(int _in, vector<int> &_mask) {
    int sp = 8;
    int mid[8] = {128,64,32,16,8,4,2,1};
    int mask[32] = {0};
    for (int i = 0; i < _in; i++) {
        mask[i] = 1;
    }

    int mask1 = 0;
    int sp1 = sp*0;
    for (int i1 = 0; i1<sp; i1++) {
        mask1 = mask1 + mid[i1]*mask[sp1+i1];
    }
    _mask.push_back(mask1);

    int mask2 = 0;
    int sp2 = sp*1;
    for (int i2 = 0; i2<sp; i2++) {
        mask2 = mask2 + mid[i2]*mask[sp2+i2];
    }
    _mask.push_back(mask2);

    int mask3 = 0;
    int sp3 = sp*2;
    for (int i3 = 0; i3<sp; i3++) {
        mask3 = mask3 + mid[i3]*mask[sp3+i3];
    }
    _mask.push_back(mask3);

    int mask4 = 0;
    int sp4 = sp*3;
    for (int i4 = 0; i4<sp; i4++) {
        mask4 = mask4 + mid[i4]*mask[sp4+i4];
    }
    _mask.push_back(mask4);
}

// subnet
static int subnet_is_belong(lua_State *L) {
    const char *_ip = luaL_checkstring(L, 1);
    const char *_cidr = luaL_checkstring(L, 2);
   
    bool ret = false;    
    vector<string> ip_vec, cidr_vec;
    vector<int> mask_vec;
    comm_ss(ip_vec, _ip,".");
    comm_ss(cidr_vec, _cidr, "/");
    if( 4 == ip_vec.size() && 2 == cidr_vec.size()) {  
        mask_convert(atoi(cidr_vec[1].c_str()),mask_vec);
		if( 4 != mask_vec.size() ) {
			ret = false ;
		} else {
			vector<string> tmp;
			for(size_t i = 0; i < mask_vec.size(); i++) {
				int imask = mask_vec[i];
				int iip = atoi(ip_vec[i].c_str());
				char ctmp[4] = "";
				sprintf(ctmp, "%d", (imask & iip));
				tmp.push_back(ctmp);
			}
			
			string str_tmp = "";
			for(size_t j = 0; j < tmp.size(); j++) {
				if(j == (tmp.size()-1)) {
					str_tmp = str_tmp + tmp[j];
				} else {
					str_tmp = str_tmp + tmp[j] + ".";
				}
			} 
			ret = (str_tmp == cidr_vec[0]);
		}
    } else {
        ret = false;
    }    
    lua_pushboolean(L, ret);
    return 1;
}

// weight
static int weighted_random(lua_State *L) {
    int ret = -1;
    string _weight = luaL_checkstring(L, 1);
    vector<int> wei_vec;
    int radom_max = 0;
    vector<string> tmp;
    comm_ss(tmp, _weight, ",");
    for(size_t i = 0; i < tmp.size(); i++){
        int item = atoi(tmp[i].c_str());
        radom_max = radom_max + item;
        for (int j = 0; j < item; j++) {
            wei_vec.push_back(i);
        }
    }
    int tt = rand()%radom_max + 1;
    ret = wei_vec[tt-1];
    
    lua_pushnumber(L, ret);
    return 1;
}

static int init_weighted_random(lua_State *L) {
    srand((unsigned)time(NULL));
    lua_pushboolean(L,true);
    return 1;
}

static const struct luaL_Reg algorithm[] = {
    {"subnet_is_belong" , subnet_is_belong},
    {"init_weighted_random" , init_weighted_random},
    {"weighted_random" , weighted_random},
    {NULL, NULL}
};

int luaopen_algorithm(lua_State *L) {
    luaL_register(L, "algorithm",algorithm);
    return 1;
}
