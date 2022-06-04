import pybaseball as pyb

player = pyb.playerid_lookup('perez', 'salvador')
player_id = int(player.key_mlbam)
start_date = '2021-03-31'
end_date = '2021-09-30'

df = pyb.statcast_batter(start_date, end_date, player_id)

home_df = df.loc[df['home_team'] == 'KC']
home_df.to_csv('C:/Users/leone/OneDrive/Documents/Playground/Datasets/salvador_perez.csv')
pyb.spraychart(home_df, 'royals', title = 'Salvador Perez MAR-SEP', colorby='bb_type')