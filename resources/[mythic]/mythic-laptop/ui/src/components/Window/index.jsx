import React, { useRef } from 'react';
import { Grid, Button } from '@mui/material';
import { makeStyles } from '@mui/styles';
import { FontAwesomeIcon } from '@fortawesome/react-fontawesome';
import Draggable from 'react-draggable'; // The default
import { useDispatch, useSelector } from 'react-redux';

export default ({
	title,
	children,
	app,
	appState,
	appData,
	onRefresh = null,
	color = false,
	width = '100%',
	height = '100%',
}) => {
	const dispatch = useDispatch();
	const focused = useSelector((state) => state.apps.focused);
	const useStyles = makeStyles((theme) => ({
		window: {
			position: 'absolute',
			height: '90%',
			width: '85%',
			left: 150,
			top: 40,
			zIndex: focused == app ? 200 : 100,
			border: !Boolean(appData.size)
				? 'none'
				: `2px solid ${
						focused == app
							? appData.color
							: theme.palette.secondary.main
				  }`,
		},
		titlebar: {
			height: 50,
			width: '100%',
			background:
				focused == app
					? Boolean(color)
						? color
						: theme.palette.primary.main
					: theme.palette.secondary.light,
			lineHeight: '50px',
			display: 'flex',
			userSelect: 'none',
			zIndex: focused == app ? 200 : 100,
		},
		title: {
			display: 'inline-block',
			flex: 1,
			paddingLeft: 15,
		},
		actions: {
			display: 'inline-block',
			textAlign: 'center',
		},
		appControlMinimizeBtn: {
			border: `none`,
			minWidth: `17px`,
			minHeight: `17px`,
			borderRadius: `50px`,
			marginRight: '0.5rem',
			backgroundColor: `#FFBF60`,
			'&:hover': {
				cursor: 'pointer'
			}
		},
		appControlCloseBtn: {
			border: `none`,
			minWidth: `17px`,
			minHeight: `17px`,
			borderRadius: `50px`,
			backgroundColor: `#FF6060`,
			'&:hover': {
				cursor: 'pointer'
			}
		},
		content: {
			height: 'calc(100% - 50px)',
			background: theme.palette.secondary.dark,
		},
		windowDrag: {
			visibility: appState.minimized ? 'hidden' : 'normal',
		},
	}));

	const classes = useStyles();

	const onStart = () => {
		if (focused != app) {
			dispatch({
				type: 'UPDATE_FOCUS',
				payload: {
					app,
				},
			});
		}
	};

	const onClick = () => {
		if (focused != app) {
			dispatch({
				type: 'UPDATE_FOCUS',
				payload: {
					app,
				},
			});
		}
	};

	const onMinimize = () => {
		dispatch({
			type: 'MINIMIZE_APP',
			payload: {
				app,
			},
		});
	};

	const onClose = () => {
		dispatch({
			type: 'CLOSE_APP',
			payload: {
				app,
			},
		});
	};

	return (
		<Draggable
			handle={'section'}
		>
			<div className={classes.window} onClick={onClick}>
				<section className={classes.titlebar}>
					<div className={classes.title}>{title}</div>
					<div className={classes.actions}>
						{Boolean(onRefresh) && (
							<Button fullWidth className={classes.action}>
								<FontAwesomeIcon
									icon={['fas', 'arrows-rotate']}
								/>
							</Button>
						)}

						<div
							style={{
								marginRight: '1vh'
							}}
						>
							<Button className={classes.appControlMinimizeBtn}>
								<div></div>
							</Button>
							<Button onClick={onClose} className={classes.appControlCloseBtn}>
								<div></div>
							</Button>
						</div>
					</div>
				</section>
				<div className={classes.content}>{children}</div>
			</div>
		</Draggable>
	);
};